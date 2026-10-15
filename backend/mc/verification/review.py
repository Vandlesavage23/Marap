"""Manual review queue and appeals (MC-037, MC-038). Reviewers see the vendor outcome summary only — we hold no
images. Services take a staff id + role (the admin portal supplies StaffUsers); roles are re-checked here and every
decision is audited."""

import json
import uuid
from datetime import date, datetime
from typing import TYPE_CHECKING

from django.db import IntegrityError, transaction
from django.db.models import Q
from django.utils import timezone

from mc.accounts import constants as account_status
from mc.accounts import selectors as account_selectors
from mc.accounts import services as account_services
from mc.audit import services as audit
from mc.common import events
from mc.common.crypto import hmac_value
from mc.common.errors import Conflict, Forbidden, NotFound, ValidationFailed
from mc.common.timeutil import age_on, kampala_date
from mc.notifications import services as notification_services
from mc.safety import selectors as safety_selectors

from . import reasons
from .events import AccountVerified, SafetyFlagRaised
from .models import VerificationAppeal, VerificationAttempt
from .services import _schedule_vendor_image_deletion, normalise_id_number

REVIEW_ROLES = {"verification_reviewer", "privacy_officer"}
APPEAL_ROLES = {"verification_reviewer", "privacy_officer"}
if TYPE_CHECKING:
    from mc.accounts.models import Account

MIN_AGE_DEFAULT = 18


def _role(role: str, allowed: set[str]) -> None:
    if role not in allowed:
        raise Forbidden("Your role can't do this.")


def queue(*, actor_id: uuid.UUID, role: str) -> list[dict[str, object]]:
    """Attempts awaiting a decision, oldest first. Reviewers see unassigned cases and their own."""
    _role(role, REVIEW_ROLES)
    rows = VerificationAttempt.objects.filter(status="needs_review").order_by("id")
    if role == "verification_reviewer":
        rows = rows.filter(Q(reviewed_by__isnull=True) | Q(reviewed_by=actor_id))
    return [
        {
            "attempt_id": str(a.id),
            "claimed": a.reviewed_by is not None,
            "id_type": a.id_type,
            "country": a.issuing_country,
            "outcome": _summary(a),
            "waiting_since": a.created_at,
        }
        for a in rows
    ]


def _summary(a: VerificationAttempt) -> dict[str, object]:
    try:
        return json.loads(a.vendor_result) if a.vendor_result else {}
    except ValueError:
        return {}


def claim(*, attempt_id: uuid.UUID, actor_id: uuid.UUID, role: str) -> VerificationAttempt:
    _role(role, REVIEW_ROLES)
    with transaction.atomic():
        a = (
            VerificationAttempt.objects.select_for_update()
            .filter(id=attempt_id, status="needs_review")
            .first()
        )
        if a is None:
            raise NotFound()
        if a.reviewed_by not in (None, actor_id):
            raise Conflict("Another reviewer already took this case.")
        a.reviewed_by = actor_id
        a.save(update_fields=["reviewed_by", "updated_at"])
        audit.record(
            actor_type="staff",
            actor_id=actor_id,
            role=role,
            action="verification.claim",
            target_type="verification_attempt",
            target_id=a.id,
            reason="claimed for review",
        )
    return a


def _conclude_pass(
    attempt: VerificationAttempt, *, dob: date | None, id_number: str | None, now: datetime
) -> str | None:
    """Apply the shared pass rules to a human-approved attempt. Returns a failure reason, or None if it passed."""
    account = attempt.account
    dob = attempt.date_of_birth or dob
    id_hash = (
        bytes(attempt.id_number_hmac)
        if attempt.id_number_hmac
        else (
            hmac_value(normalise_id_number(id_number), purpose="id_number")
            if id_number and normalise_id_number(id_number)
            else None
        )
    )
    if dob is None or id_hash is None or account is None:
        raise ValidationFailed(
            "Birth date and ID number are needed to approve this case.",
            needs=["date_of_birth", "id_number"],
        )
    failure = None
    if age_on(dob, kampala_date(now)) < MIN_AGE_DEFAULT:
        failure = reasons.UNDERAGE
    elif safety_selectors.is_identity_banned(id_hash):
        failure = reasons.BANNED
    elif (
        VerificationAttempt.objects.filter(
            id_number_hmac=id_hash, status="passed", account__isnull=False
        )
        .exclude(id=attempt.id)
        .exists()
    ):
        failure = reasons.DUPLICATE_IDENTITY
    attempt.date_of_birth = dob
    attempt.decided_at = now
    if failure is None:
        attempt.id_number_hmac, attempt.status, attempt.reason_code = id_hash, "passed", ""
        try:
            with transaction.atomic():
                attempt.save()
        except IntegrityError:
            failure = reasons.DUPLICATE_IDENTITY
    if failure is not None:
        attempt.status, attempt.reason_code, attempt.id_number_hmac = "failed", failure, None
        if failure in (reasons.UNDERAGE, reasons.DUPLICATE_IDENTITY):
            attempt.safety_flag = failure
            if failure == reasons.UNDERAGE:
                account_services.set_status(account=account, status=account_status.SUSPENDED)
            events.publish(
                SafetyFlagRaised(account_id=account.id, attempt_id=attempt.id, flag=failure)
            )
        attempt.save()
        return failure
    account_services.set_status(account=account, status=account_status.ACTIVE)
    events.publish(AccountVerified(account_id=account.id, attempt_id=attempt.id))
    _schedule_vendor_image_deletion(attempt)
    return None


def decide_review(
    *,
    attempt_id: uuid.UUID,
    actor_id: uuid.UUID,
    role: str,
    approve: bool,
    reason: str,
    date_of_birth: date | None = None,
    id_number: str | None = None,
) -> VerificationAttempt:
    """Approve (→ the normal pass rules still apply: adult, not banned, not a duplicate) or reject."""
    _role(role, REVIEW_ROLES)
    if not reason.strip():
        raise ValidationFailed("A reason is required.")
    now = timezone.now()
    with transaction.atomic():
        a = (
            VerificationAttempt.objects.select_for_update(of=("self",))
            .select_related("account")
            .filter(id=attempt_id, status="needs_review")
            .first()
        )
        if a is None:
            raise NotFound()
        if role == "verification_reviewer" and a.reviewed_by != actor_id:
            raise Forbidden("Claim this case before deciding it.")
        a.reviewed_by = actor_id
        outcome = "rejected"
        if approve:
            failure = _conclude_pass(a, dob=date_of_birth, id_number=id_number, now=now)
            outcome = "passed" if failure is None else f"failed:{failure}"
        else:
            a.status, a.reason_code, a.decided_at = "failed", "rejected_by_review", now
            a.save()
        audit.record(
            actor_type="staff",
            actor_id=actor_id,
            role=role,
            action="verification.review",
            target_type="verification_attempt",
            target_id=a.id,
            reason=reason,
            metadata={"outcome": outcome},
        )
        if a.account_id:
            notification_services.notify(
                account_id=a.account_id, type="verification_decided", payload={"status": a.status}
            )
    return a


# ----------------------------------------------------------------------------- appeals (MC-038)
APPEALABLE_BLOCKED = reasons.NO_APPEAL


def open_appeal(
    *, account: "Account", attempt_id: uuid.UUID | None, message: str
) -> VerificationAppeal:
    """Appeal a *final* failure (not underage / duplicate identity / banned — those are support-only). One open
    appeal per attempt."""
    message = message.strip()
    if not 10 <= len(message) <= 1000:
        raise ValidationFailed("Please explain in 10-1,000 characters.")
    qs = VerificationAttempt.objects.filter(account=account, status="failed").order_by("-id")
    attempt = qs.filter(id=attempt_id).first() if attempt_id else qs.first()
    if attempt is None:
        raise NotFound()
    if attempt.reason_code in APPEALABLE_BLOCKED:
        raise Forbidden("This decision can only be reviewed by our support team.")
    try:
        with transaction.atomic():
            appeal = VerificationAppeal.objects.create(
                attempt=attempt, account=account, message=message
            )
    except IntegrityError:
        raise Conflict("You already have an open appeal for this attempt.") from None
    audit.record(
        actor_type="member",
        actor_id=account.id,
        action="verification.appeal_opened",
        target_type="verification_attempt",
        target_id=attempt.id,
        reason="member appeal",
    )
    return appeal


def decide_appeal(
    *,
    appeal_id: uuid.UUID,
    actor_id: uuid.UUID,
    role: str,
    uphold: bool,
    reason: str,
    date_of_birth: date | None = None,
    id_number: str | None = None,
) -> VerificationAppeal:
    """Upheld → the attempt is re-decided as passed (same pass rules). Rejected → stays failed. Member notified."""
    _role(role, APPEAL_ROLES)
    if not reason.strip():
        raise ValidationFailed("A reason is required.")
    now = timezone.now()
    with transaction.atomic():
        appeal = (
            VerificationAppeal.objects.select_for_update(of=("self",))
            .select_related("attempt", "attempt__account")
            .filter(id=appeal_id)
            .first()
        )
        if appeal is None:
            raise NotFound()
        if appeal.status != VerificationAppeal.Status.OPEN:
            raise Conflict("This appeal was already decided.")
        attempt = appeal.attempt
        if uphold:
            failure = _conclude_pass(attempt, dob=date_of_birth, id_number=id_number, now=now)
            if failure is not None:
                raise ValidationFailed(
                    "The pass rules still fail for this identity.", reason=failure
                )
            attempt.reviewed_by = actor_id
            attempt.save(update_fields=["reviewed_by", "updated_at"])
        appeal.status = (
            VerificationAppeal.Status.UPHELD if uphold else VerificationAppeal.Status.REJECTED
        )
        appeal.decided_by, appeal.decided_at, appeal.decision_reason = actor_id, now, reason[:500]
        appeal.save(
            update_fields=["status", "decided_by", "decided_at", "decision_reason", "updated_at"]
        )
        audit.record(
            actor_type="staff",
            actor_id=actor_id,
            role=role,
            action="verification.appeal_decided",
            target_type="verification_attempt",
            target_id=attempt.id,
            reason=reason,
            metadata={"upheld": str(uphold)},
        )
        if appeal.account_id:
            notification_services.notify(
                account_id=appeal.account_id,
                type="verification_decided",
                payload={"status": "passed" if uphold else "failed", "appeal": "true"},
            )
    return appeal


_ = account_selectors

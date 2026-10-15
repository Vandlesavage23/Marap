"""Account deletion (Bible §10.9, MC-110).

`request_deletion` deactivates immediately (hidden everywhere, signed out, matches closed, pending interests
cancelled) and schedules a hard delete after the grace period unless a legal/safety hold applies.
`run_hard_deletions` (daily) performs the erasure. RETAINED by design: the trial identity hash, the verification
decision (status, dob, id hash), payment events and purchases (tax law), audit events, and reports involving the
member (pseudonymised: the member link is cleared)."""

import logging
import uuid
from datetime import datetime, timedelta
from typing import TYPE_CHECKING

from django.conf import settings
from django.db import transaction
from django.utils import timezone

from mc.accounts import constants as account_status
from mc.accounts import selectors as account_selectors
from mc.accounts import services as account_services
from mc.adminportal import services as adminportal_services
from mc.audit import services as audit
from mc.beta import services as beta_services
from mc.common.errors import Conflict, Forbidden
from mc.entitlements import selectors as entitlement_selectors
from mc.interests import services as interest_services
from mc.matches import services as match_services
from mc.media import services as media_services
from mc.messaging import services as messaging_services
from mc.safety import selectors as safety_selectors

from .models import PrivacyRequest

if TYPE_CHECKING:
    from mc.accounts.models import Account

logger = logging.getLogger(__name__)


def request_deletion(*, account: "Account", code: str) -> tuple[PrivacyRequest, dict[str, object]]:
    """Needs a fresh OTP code (sent by `start_reauth`). Idempotent while a request is open."""
    now = timezone.now()
    open_request = PrivacyRequest.objects.filter(
        account_ref=account.id, kind=PrivacyRequest.Kind.DELETE, status__in=["pending", "held"]
    ).first()
    if open_request is None and not account_selectors.verify_reauth_code(
        account=account, code=code
    ):
        raise Forbidden("That confirmation code is invalid or has expired.")
    with transaction.atomic():
        existing = open_request
        sub_active = _has_active_subscription(account)
        if existing is None:
            existing = PrivacyRequest.objects.create(
                account=account, account_ref=account.id, kind=PrivacyRequest.Kind.DELETE,
                requested_at=now, due_at=now + timedelta(days=settings.DELETION_GRACE_DAYS),
            )  # fmt: skip
            match_services.end_all_for(account_id=account.id, reason="deleted")
            interest_services.cancel_all_for(account_id=account.id)
            from mc.profiles import services as profile_services

            profile_services.suspend_profile(account_id=account.id)
            account_services.set_status(
                account=account, status=account_status.DEACTIVATED
            )  # signs out everywhere
            audit.record(actor_type="member", actor_id=account.id, action="privacy.deletion_requested", target_type="account", target_id=account.id,
                         reason="member request", metadata={"due_at": existing.due_at.isoformat() if existing.due_at else ""})  # fmt: skip
    return existing, {
        "status": "deactivated",
        "hard_delete_after": existing.due_at,
        "active_subscription": sub_active,
        "subscription_note": (
            "Deleting your account doesn't cancel an App Store or Google Play subscription. "
            "Cancel it in your store's subscription settings to stop renewals."
            if sub_active
            else ""
        ),
    }


def _has_active_subscription(account: "Account") -> bool:
    return entitlement_selectors.membership_ends_at(account.id) is not None


def cancel_deletion(*, account_id: uuid.UUID, actor_id: uuid.UUID, role: str) -> None:
    """Support/privacy officer restores an account still inside the grace period (audited)."""
    with transaction.atomic():
        req = (
            PrivacyRequest.objects.select_for_update()
            .filter(account_ref=account_id, kind="delete", status__in=["pending", "held"])
            .first()
        )
        if req is None:
            raise Conflict("No open deletion request.")
        req.status, req.completed_at = PrivacyRequest.Status.CANCELLED, timezone.now()
        req.save(update_fields=["status", "completed_at", "updated_at"])
        account = account_selectors.get_account(account_id)
        if account is not None:
            account_services.set_status(account=account, status=account_status.ACTIVE)
        audit.record(
            actor_type="staff",
            actor_id=actor_id,
            role=role,
            action="privacy.deletion_cancelled",
            target_type="account",
            target_id=account_id,
            reason="restored within grace",
        )


def run_hard_deletions(*, now: datetime | None = None) -> dict[str, int]:
    """Daily job: erase accounts whose grace period ended (unless held). Idempotent and resumable."""
    now = now or timezone.now()
    out = {"deleted": 0, "held": 0}
    due = PrivacyRequest.objects.filter(
        kind=PrivacyRequest.Kind.DELETE, status__in=["pending", "held"], due_at__lte=now
    )
    for req in due:
        hold = safety_selectors.has_deletion_hold(req.account_ref)
        if hold:
            PrivacyRequest.objects.filter(id=req.id).update(
                status="held", hold_reason=hold, updated_at=now
            )
            out["held"] += 1
            continue
        account = account_selectors.get_account(req.account_ref)
        with transaction.atomic():
            if account is not None:
                _erase(account)
            PrivacyRequest.objects.filter(id=req.id).update(
                status="completed", completed_at=now, hold_reason="", account=None, updated_at=now
            )
            audit.record(
                actor_type="system",
                action="privacy.account_deleted",
                target_type="account",
                target_id=req.account_ref,
                reason="grace period ended",
            )
        out["deleted"] += 1
    return out


def _erase(account: "Account") -> None:
    media_services.delete_all_for(account_id=account.id)  # stored files first, then rows
    messaging_services.scrub_sent_by(account_id=account.id)
    interest_services.purge_for(account_id=account.id)
    adminportal_services.purge_notes_for(account.id)
    beta_services.purge_for(account.id)
    account_services.hard_delete_account(
        account=account
    )  # cascades profile, answers, devices, sessions, consents…

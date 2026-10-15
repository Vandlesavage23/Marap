"""Verification write operations and the state machine (Bible §10.2).

created ─(SDK submitted)→ submitted ─(callback/poll)→ passed | failed | needs_review | error
Pass requires ALL: vendor passed; document not expired; liveness; face match; date of birth present
and age ≥ MIN_AGE on the decision date (Africa/Kampala); id number present and not already used by
another passed account.
"""

import json
import uuid
from collections.abc import Mapping
from datetime import date, datetime, timedelta
from typing import TYPE_CHECKING
from zoneinfo import ZoneInfo

from django.conf import settings
from django.db import IntegrityError, transaction
from django.utils import timezone

from mc.accounts import constants as account_status
from mc.accounts import selectors as account_selectors
from mc.accounts import services as account_services
from mc.common import events
from mc.common.crypto import hmac_value
from mc.common.errors import (
    Duplicate,
    Forbidden,
    LimitReached,
    NotFound,
    ValidationFailed,
    VerificationPending,
)

from . import reasons, selectors
from .events import AccountVerified, SafetyFlagRaised
from .models import VerificationAttempt
from .providers import get_identity_provider
from .providers.base import VendorResult

if TYPE_CHECKING:
    from mc.accounts.models import Account

KAMPALA = ZoneInfo("Africa/Kampala")
TERMINAL = {"passed", "failed", "error", "expired"}


def kampala_date(moment: datetime) -> date:
    return moment.astimezone(KAMPALA).date()


def age_on(dob: date, on: date) -> int:
    return on.year - dob.year - ((on.month, on.day) < (dob.month, dob.day))


def normalise_id_number(raw: str) -> str:
    return "".join(ch for ch in raw.upper() if ch.isalnum())


# ----------------------------------------------------------------- MC-035
def create_session(
    *, account: "Account", id_type: str = "", issuing_country: str = ""
) -> tuple[VerificationAttempt, dict]:
    """Create a vendor job and return `(attempt, sdk_params)`. Params are signed server-side; vendor
    secrets never reach the client."""
    if account.status != account_status.PENDING_VERIFICATION:
        if account.status == account_status.ACTIVE:
            raise Duplicate("This account is already verified.")
        raise Forbidden("Verification isn't available for this account.")
    if id_type and id_type not in settings.VERIFICATION_ALLOWED_ID_TYPES:
        raise ValidationFailed("Unsupported ID type.")
    account_services.require_verification_consents(account)

    with transaction.atomic():
        # serialise concurrent starts for one account
        locked = account_selectors.lock_account(account.id)
        pending = VerificationAttempt.objects.filter(
            account=locked, status__in=["submitted", "needs_review"]
        ).exists()
        if pending:
            raise VerificationPending("We're still checking your previous submission.")
        if selectors.attempts_in_last_24h(locked) >= settings.VERIFICATION_AUTO_ATTEMPTS_PER_DAY:
            raise LimitReached(
                "You've reached today's verification limit. Please try again tomorrow or contact support.",
                retry_after=24 * 3600,
            )
        job_id = f"mc_{uuid.uuid4().hex}"
        attempt = VerificationAttempt.objects.create(
            account=locked, vendor_job_id=job_id, id_type=id_type, issuing_country=issuing_country
        )
    params = get_identity_provider().create_job(job_id=job_id, user_id=str(account.id))
    return attempt, params


def mark_submitted(*, account: "Account", attempt_id: uuid.UUID) -> VerificationAttempt:
    """The app tells us the SDK capture finished (starts the polling-fallback clock)."""
    with transaction.atomic():
        att = (
            VerificationAttempt.objects.select_for_update()
            .filter(id=attempt_id, account=account)
            .first()
        )
        if att is None:
            raise NotFound()
        if att.status == "created":
            att.status, att.submitted_at = "submitted", timezone.now()
            att.save(update_fields=["status", "submitted_at", "updated_at"])
    return att


# ----------------------------------------------------------------- MC-036
def handle_vendor_callback(
    *, body: bytes, headers: Mapping[str, str]
) -> VerificationAttempt | None:
    provider = get_identity_provider()
    if not provider.verify_callback(body=body, headers=headers):
        raise Forbidden("Invalid signature.")
    try:
        result = provider.parse_callback(body=body)
    except (ValueError, KeyError) as exc:
        raise ValidationFailed("Malformed callback.") from exc
    return apply_result(result)


def apply_result(result: VendorResult) -> VerificationAttempt | None:
    """Apply a vendor outcome exactly once; replays/late duplicates are ignored."""
    flag: tuple[Account, VerificationAttempt, str] | None = None
    verified: tuple[Account, VerificationAttempt] | None = None
    with transaction.atomic():
        attempt = (
            VerificationAttempt.objects.select_for_update()
            .select_related("account")
            .filter(vendor_job_id=result.job_id)
            .first()
        )
        if attempt is None:
            raise NotFound()
        if attempt.status in TERMINAL or attempt.status == "needs_review":
            return attempt  # idempotent; a reviewer owns needs_review attempts (MC-037)
        now = timezone.now()
        attempt.decided_at = now
        attempt.id_type = result.id_type or attempt.id_type
        attempt.issuing_country = result.issuing_country or attempt.issuing_country
        attempt.vendor_result = json.dumps(
            {"outcome": result.outcome, "reason": result.vendor_reason, **result.summary}
        )
        account = attempt.account

        if result.outcome == "error":
            attempt.status, attempt.reason_code = "error", reasons.VENDOR_ERROR
        elif result.outcome == "needs_review":
            attempt.status, attempt.decided_at = "needs_review", None
        elif result.outcome == "failed":
            attempt.status = "failed"
            attempt.reason_code = result.vendor_reason or reasons.UNKNOWN
            if (
                result.date_of_birth
                and age_on(result.date_of_birth, kampala_date(now)) < settings.MIN_AGE
            ):
                attempt.reason_code = reasons.UNDERAGE
        else:
            failure = _pass_failure(result, now)
            if failure is None:
                attempt.date_of_birth = result.date_of_birth
                attempt.id_number_hmac = hmac_value(
                    normalise_id_number(result.id_number or ""), purpose="id_number"
                )
                attempt.status = "passed"
            else:
                attempt.status, attempt.reason_code = "failed", failure
                if failure == reasons.UNDERAGE:
                    attempt.date_of_birth = result.date_of_birth

        if attempt.status == "passed":
            try:
                with transaction.atomic():
                    attempt.save()
            except IntegrityError:  # another account verified this identity first
                attempt.status, attempt.reason_code = "failed", reasons.DUPLICATE_IDENTITY
                attempt.id_number_hmac = None
                attempt.date_of_birth = None
                attempt.save()

        if attempt.status == "passed":
            account_services.set_status(account=account, status=account_status.ACTIVE)
            verified = (account, attempt)
        else:
            if attempt.reason_code in (reasons.UNDERAGE, reasons.DUPLICATE_IDENTITY):
                attempt.safety_flag = attempt.reason_code
                if attempt.reason_code == reasons.UNDERAGE:
                    account_services.set_status(account=account, status=account_status.SUSPENDED)
                flag = (account, attempt, attempt.reason_code)
            attempt.save()

        if verified:
            events.publish(AccountVerified(account_id=account.id, attempt_id=attempt.id))
            _schedule_vendor_image_deletion(attempt)
        if flag:
            events.publish(
                SafetyFlagRaised(account_id=account.id, attempt_id=attempt.id, flag=flag[2])
            )
    return attempt


def _pass_failure(result: VendorResult, now: datetime) -> str | None:
    if result.document_expired:
        return reasons.DOC_EXPIRED
    if not result.liveness_passed:
        return reasons.LIVENESS_FAILED
    if not result.face_match_passed:
        return reasons.FACE_MISMATCH
    if result.date_of_birth is None:
        return reasons.DOB_MISSING
    if age_on(result.date_of_birth, kampala_date(now)) < settings.MIN_AGE:
        return reasons.UNDERAGE
    if not result.id_number or not normalise_id_number(result.id_number):
        return reasons.ID_NUMBER_MISSING
    id_hmac = hmac_value(normalise_id_number(result.id_number), purpose="id_number")
    if VerificationAttempt.objects.filter(id_number_hmac=id_hmac, status="passed").exists():
        return reasons.DUPLICATE_IDENTITY
    return None


def _schedule_vendor_image_deletion(attempt: VerificationAttempt) -> None:
    from .tasks import delete_vendor_images

    delay = settings.VERIFICATION_VENDOR_IMAGE_DELETE_DAYS * 24 * 3600
    job = attempt.vendor_job_id
    transaction.on_commit(lambda: delete_vendor_images.apply_async(args=[job], countdown=delay))


# ----------------------------------------------------------------- polling fallback
def poll_stale_attempts(*, now: datetime | None = None) -> int:
    """Beat job: for attempts with no callback after N minutes, ask the vendor; expire after 24 h."""
    now = now or timezone.now()
    cutoff = now - timedelta(minutes=settings.VERIFICATION_POLL_AFTER_MINUTES)
    expire_cutoff = now - timedelta(hours=settings.VERIFICATION_EXPIRE_AFTER_HOURS)
    provider = get_identity_provider()
    resolved = 0
    stale = VerificationAttempt.objects.filter(
        status__in=["created", "submitted"], created_at__lte=cutoff
    )
    for attempt in stale:
        result = provider.fetch_job_status(job_id=attempt.vendor_job_id)
        if result is not None:
            apply_result(result)
            resolved += 1
        elif attempt.created_at <= expire_cutoff:
            VerificationAttempt.objects.filter(
                id=attempt.id, status__in=["created", "submitted"]
            ).update(status="expired", decided_at=now)
            resolved += 1
    return resolved

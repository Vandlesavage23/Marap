"""Recovery email + lost-phone recovery (MC-112, Bible §10.1 step 4).

Changing the phone number is the most dangerous account action, so it needs ALL of: a verified recovery email
(OTP), a live biometric re-check against the member's enrolled face, and an OTP on the NEW phone. Every step is
rate-limited, the final swap signs out every device, and the old phone and email are told.
"""

import contextlib
import hmac
import secrets
import uuid
from datetime import timedelta
from typing import TYPE_CHECKING

from django.conf import settings
from django.core import signing
from django.db import IntegrityError, transaction
from django.utils import timezone

from mc.audit import services as audit
from mc.common import ratelimit
from mc.common.crypto import hmac_value
from mc.common.errors import Conflict, Forbidden, ValidationFailed
from mc.common.redis import get_redis

from . import constants, selectors, services
from . import phone as phone_utils
from .models import Account, RecoverySession
from .providers.email import get_email_provider
from .providers.sms import get_sms_provider

if TYPE_CHECKING:
    pass

HOUR = 3600
SALT = "accounts.recovery"
BIOMETRIC_PREFIX = "mcr_"


# ---- tiny one-time-code store (Redis) ----------------------------------------------------------
def _store_code(key: str, code: str, payload: str = "") -> None:
    r = get_redis()
    pipe = r.pipeline()
    pipe.delete(key)
    pipe.hset(
        key,
        mapping={
            "h": hmac_value(f"{key}|{code}", purpose="otp").hex(),
            "attempts": 0,
            "payload": payload,
        },
    )
    pipe.expire(key, settings.OTP_TTL_MINUTES * 60)
    pipe.execute()


def _consume_code(key: str, code: str) -> str | None:
    """Payload if `code` is right (single use, 5 attempts), else None."""
    r = get_redis()
    stored = r.hget(key, "h")
    if stored is None:
        return None
    attempts = r.hincrby(key, "attempts", 1)
    if attempts > settings.OTP_MAX_VERIFY_ATTEMPTS:
        r.delete(key)
        return None
    good = hmac.compare_digest(
        stored.decode() if isinstance(stored, bytes) else stored,
        hmac_value(f"{key}|{code}", purpose="otp").hex(),
    )
    if not good:
        if attempts >= settings.OTP_MAX_VERIFY_ATTEMPTS:
            r.delete(key)
        return None
    payload = r.hget(key, "payload")
    if not r.delete(key):
        return None
    return (payload.decode() if isinstance(payload, bytes) else payload) or ""


def _new_code() -> str:
    return f"{secrets.randbelow(10**6):06d}"


# ---- recovery email ------------------------------------------------------------------------------
def start_email_verification(*, account: Account, email: str, ip: str) -> None:
    """Send a code to a new recovery email (authenticated member)."""
    email = email.strip().lower()
    if "@" not in email or len(email) > 254:
        raise ValidationFailed("Enter a valid email address.")
    ratelimit.hit(
        f"email:send:{account.id}", limit=settings.RECOVERY_EMAIL_OTPS_PER_HOUR, window_seconds=HOUR
    )
    if Account.objects.filter(email__iexact=email).exclude(id=account.id).exists():
        return  # silently: never reveal that an address is in use
    code = _new_code()
    _store_code(f"otp:email:{account.id}", code, payload=email)
    get_email_provider().send(
        to=email,
        subject="Your Marriage Connect email code",
        body=f"Your code is {code}. It expires in {settings.OTP_TTL_MINUTES} minutes.",
    )


def confirm_email(*, account: Account, code: str) -> Account:
    email = _consume_code(f"otp:email:{account.id}", code)
    if not email:
        raise ValidationFailed("That code is invalid or has expired.")
    try:
        with transaction.atomic():
            account.email, account.email_verified_at = email, timezone.now()
            account.save(update_fields=["email", "email_verified_at", "updated_at"])
    except IntegrityError:
        raise ValidationFailed("That code is invalid or has expired.") from None
    return account


# ---- lost-phone recovery -----------------------------------------------------------------------
def start_recovery(*, phone: str, ip: str) -> None:
    """Always returns normally (no enumeration). Sends an email code only if the account has a verified email."""
    e164 = phone_utils.normalise(phone)
    ratelimit.hit(
        f"recover:ip:{hmac_value(ip, purpose='ip').hex()[:32]}", limit=10, window_seconds=HOUR
    )
    ratelimit.hit(
        f"recover:phone:{hmac_value(e164, purpose='phone').hex()}",
        limit=settings.RECOVERY_EMAIL_OTPS_PER_HOUR,
        window_seconds=HOUR,
    )
    account = selectors.get_account_by_phone(e164)
    if (
        account is None
        or not account.email
        or account.email_verified_at is None
        or account.status in (constants.DEACTIVATED, constants.DELETED)
    ):
        return
    session = RecoverySession.objects.create(
        account=account,
        expires_at=timezone.now() + timedelta(minutes=settings.RECOVERY_TTL_MINUTES),
        ip_hmac=hmac_value(ip, purpose="ip"),
    )
    code = _new_code()
    _store_code(f"otp:recover:{session.id}", code)
    get_email_provider().send(
        to=account.email,
        subject="Marriage Connect account recovery",
        body=f"Your recovery code is {code}. If this wasn't you, ignore this email.",
    )


def verify_email(*, phone: str, code: str) -> tuple[str, dict[str, object]]:
    """Email code → recovery token + biometric SDK params for the re-check."""
    from mc.verification.providers import get_identity_provider

    e164 = phone_utils.normalise(phone)
    account = selectors.get_account_by_phone(e164)
    session = (
        RecoverySession.objects.filter(
            account=account, state=RecoverySession.State.EMAIL_SENT, expires_at__gt=timezone.now()
        )
        .order_by("-id")
        .first()
        if account
        else None
    )
    if session is None or _consume_code(f"otp:recover:{session.id}", code) is None:
        raise ValidationFailed("That code is invalid or has expired.")
    job_id = f"{BIOMETRIC_PREFIX}{uuid.uuid4().hex}"
    session.state, session.biometric_job_id = RecoverySession.State.BIOMETRIC_PENDING, job_id
    session.save(update_fields=["state", "biometric_job_id", "updated_at"])
    params = get_identity_provider().create_job(job_id=job_id, user_id=str(account.id))  # type: ignore[union-attr]
    return signing.dumps({"rs": str(session.id)}, salt=SALT), params


def biometric_result(*, job_id: str, passed: bool) -> None:
    """Called by the identity-vendor webhook for jobs we created with the recovery prefix (idempotent)."""
    with transaction.atomic():
        s = RecoverySession.objects.select_for_update().filter(biometric_job_id=job_id).first()
        if s is None or s.state != RecoverySession.State.BIOMETRIC_PENDING:
            return
        s.state = (
            RecoverySession.State.BIOMETRIC_PASSED
            if passed and s.expires_at > timezone.now()
            else RecoverySession.State.FAILED
        )
        s.save(update_fields=["state", "updated_at"])
        audit.record(
            actor_type="system",
            action="account.recovery_biometric",
            target_type="account",
            target_id=s.account_id,
            reason="biometric re-check",
            metadata={"passed": str(passed), "session": str(s.id)},
        )


def _session(token: str, *, state: str) -> RecoverySession:
    try:
        sid = signing.loads(token, salt=SALT, max_age=settings.RECOVERY_TTL_MINUTES * 60)["rs"]
    except signing.BadSignature:
        raise Forbidden("This recovery link has expired. Please start again.") from None
    s = (
        RecoverySession.objects.select_related("account")
        .filter(id=sid, state=state, expires_at__gt=timezone.now())
        .first()
    )
    if s is None:
        raise Forbidden("This recovery step isn't available. Please start again.")
    return s


def biometric_state(*, token: str) -> str:
    try:
        sid = signing.loads(token, salt=SALT, max_age=settings.RECOVERY_TTL_MINUTES * 60)["rs"]
    except signing.BadSignature:
        raise Forbidden("This recovery link has expired. Please start again.") from None
    s = RecoverySession.objects.filter(id=sid).first()
    if s is None:
        raise Forbidden("Unknown recovery.")
    return str(s.state)


def start_new_phone(*, token: str, new_phone: str, ip: str) -> None:
    """After the biometric pass: send an OTP to the NEW number (never to the old one)."""
    s = _session(token, state=RecoverySession.State.BIOMETRIC_PASSED)
    e164 = phone_utils.normalise(new_phone)
    if phone_utils.calling_code(e164) not in settings.OTP_ALLOWED_CALLING_CODES:
        raise ValidationFailed("Sign-in from this country isn't supported yet.")
    if e164 == s.account.phone_e164:
        raise ValidationFailed("That's already your number.")
    ratelimit.hit(
        f"otp:send:phone:{hmac_value(e164, purpose='phone').hex()}",
        limit=settings.OTP_SENDS_PER_PHONE_PER_HOUR,
        window_seconds=HOUR,
    )
    ratelimit.hit(
        f"otp:send:ip:{hmac_value(ip, purpose='ip').hex()[:32]}",
        limit=settings.OTP_SENDS_PER_IP_PER_HOUR,
        window_seconds=HOUR,
    )
    if Account.objects.filter(phone_e164=e164).exists():
        return  # no enumeration: the swap will fail at completion without saying why
    code = _new_code()
    _store_code(f"otp:newphone:{s.id}", code, payload=e164)
    get_sms_provider().send(
        to_e164=e164, body=f"Your Marriage Connect code is {code}. Never share it with anyone."
    )


def complete(*, token: str, code: str, ip: str) -> None:
    """Swap the phone number. Signs out every device and tells the old phone and the recovery email."""
    s = _session(token, state=RecoverySession.State.BIOMETRIC_PASSED)
    new_phone = _consume_code(f"otp:newphone:{s.id}", code)
    if not new_phone:
        raise ValidationFailed("That code is invalid or has expired.")
    old_phone, email = s.account.phone_e164, s.account.email
    try:
        with transaction.atomic():
            account = Account.objects.select_for_update().get(id=s.account_id)
            account.phone_e164 = new_phone
            account.save(update_fields=["phone_e164", "updated_at"])
            services.revoke_all_sessions(account=account, reason="account")
            s.state, s.completed_at = RecoverySession.State.COMPLETED, timezone.now()
            s.save(update_fields=["state", "completed_at", "updated_at"])
            audit.record(actor_type="member", actor_id=account.id, action="account.phone_changed", target_type="account", target_id=account.id,
                         reason="lost-phone recovery", ip=ip, metadata={"session": str(s.id)})  # fmt: skip
    except IntegrityError:
        raise Conflict("That number can't be used. Please contact support.") from None
    for notice in (
        lambda: get_sms_provider().send(
            to_e164=old_phone,
            body="Marriage Connect: the phone number on your account was changed. If this wasn't you, contact support now.",
        ),
        lambda: (
            get_email_provider().send(
                to=email or "",
                subject="Your phone number was changed",
                body="The phone number on your Marriage Connect account was changed. If this wasn't you, contact support immediately.",
            )
            if email
            else None
        ),
    ):
        with contextlib.suppress(
            Exception
        ):  # a failed courtesy notice must not undo a completed recovery
            notice()

"""Accounts write operations (Bible §6.1, §10.1). Services raise domain errors, never HTTP."""

import hmac
import secrets
import uuid
from dataclasses import dataclass
from datetime import timedelta
from typing import Any

from django.conf import settings
from django.db import IntegrityError, transaction
from django.utils import timezone

from mc.common import events, ratelimit
from mc.common.crypto import hmac_value
from mc.common.errors import Forbidden, Unauthenticated, ValidationFailed
from mc.common.redis import get_redis

from . import phone as phone_utils
from . import selectors, tokens
from .events import ConsentChanged, NewDeviceSignIn
from .models import Account, ConsentRecord, Device, Session
from .providers.sms import get_sms_provider
from .tasks import send_new_device_alert

HOUR = 3600
GENERIC_BAD_CODE = "That code is invalid or has expired."


# ---------------------------------------------------------------- OTP (MC-031)
def _otp_key(purpose: str, e164: str) -> str:
    return f"otp:{purpose}:{hmac_value(e164, purpose='phone').hex()}"


def _code_hash(e164: str, code: str) -> str:
    return hmac_value(f"{e164}|{code}", purpose="otp").hex()


def start_otp(*, phone: str, purpose: str, ip: str) -> None:
    """Send a 6-digit code. Always succeeds from the caller's view for well-formed numbers
    (no account enumeration): `recover` for an unknown phone silently sends nothing."""
    if purpose not in ("login", "recover"):
        raise ValidationFailed("Unknown purpose.")
    e164 = phone_utils.normalise(phone)
    if phone_utils.calling_code(e164) not in settings.OTP_ALLOWED_CALLING_CODES:
        raise ValidationFailed("Sign-in from this country isn't supported yet.")

    ip_id = hmac_value(ip, purpose="ip").hex()[:32]
    ratelimit.hit(
        f"otp:send:ip:{ip_id}", limit=settings.OTP_SENDS_PER_IP_PER_HOUR, window_seconds=HOUR
    )
    ratelimit.hit(
        f"otp:send:phone:{hmac_value(e164, purpose='phone').hex()}",
        limit=settings.OTP_SENDS_PER_PHONE_PER_HOUR,
        window_seconds=HOUR,
    )
    ratelimit.hit(
        f"otp:send:prefix:{e164[:7]}",
        limit=settings.OTP_SENDS_PER_PREFIX_PER_HOUR,
        window_seconds=HOUR,
    )

    if purpose == "recover" and selectors.get_account_by_phone(e164) is None:
        return

    code = f"{secrets.randbelow(10**6):06d}"
    r = get_redis()
    key = _otp_key(purpose, e164)
    pipe = r.pipeline()
    pipe.delete(key)
    pipe.hset(key, mapping={"code_hash": _code_hash(e164, code), "attempts": 0})
    pipe.expire(key, settings.OTP_TTL_MINUTES * 60)
    pipe.execute()
    get_sms_provider().send(
        to_e164=e164,
        body=f"Your Marriage Connect code is {code}. Never share it with anyone.",
    )


def _check_otp(*, e164: str, code: str, purpose: str) -> None:
    r = get_redis()
    key = _otp_key(purpose, e164)
    stored = r.hget(key, "code_hash")
    if stored is None:
        raise ValidationFailed(GENERIC_BAD_CODE)
    attempts = r.hincrby(key, "attempts", 1)
    if attempts > settings.OTP_MAX_VERIFY_ATTEMPTS:
        r.delete(key)
        raise ValidationFailed(GENERIC_BAD_CODE)
    if not hmac.compare_digest(
        stored.decode() if isinstance(stored, bytes) else stored, _code_hash(e164, code)
    ):
        if attempts >= settings.OTP_MAX_VERIFY_ATTEMPTS:
            r.delete(key)  # 5 wrong attempts burn the challenge
        raise ValidationFailed(GENERIC_BAD_CODE)
    # single use: only the caller that deletes the key wins (guards parallel verifies)
    if not r.delete(key):
        raise ValidationFailed(GENERIC_BAD_CODE)


# ---------------------------------------------------------------- sessions (MC-032)
@dataclass(frozen=True)
class AuthResult:
    access: str
    refresh: str
    account: Account
    session: Session
    created: bool


def _create_session(
    *,
    account: Account,
    device: Device | None,
    chain_id: uuid.UUID | None = None,
    rotated_from: Session | None = None,
) -> tuple[Session, str]:
    now = timezone.now()
    refresh = tokens.new_refresh_token()
    session = Session(
        account=account,
        device=device,
        chain_id=chain_id or uuid.uuid4(),
        refresh_token_hash=tokens.hash_refresh_token(refresh),
        issued_at=now,
        expires_at=now + timedelta(days=settings.REFRESH_TOKEN_DAYS),
        rotated_from=rotated_from,
    )
    session.save()
    return session, refresh


def verify_otp(
    *, phone: str, code: str, ip: str, device: dict[str, Any] | None = None
) -> AuthResult:
    """Verify a login code; creates the account for a new phone. Returns tokens."""
    e164 = phone_utils.normalise(phone)
    ratelimit.hit(
        f"otp:verify:ip:{hmac_value(ip, purpose='ip').hex()[:32]}",
        limit=settings.OTP_VERIFY_PER_IP_PER_HOUR,
        window_seconds=HOUR,
    )
    _check_otp(e164=e164, code=code, purpose="login")

    with transaction.atomic():
        account = selectors.get_account_by_phone(e164)
        created = account is None
        if account is None:
            try:
                with transaction.atomic():
                    account = Account.objects.create(phone_e164=e164, country_of_residence="")
            except IntegrityError:  # concurrent first sign-in of the same phone
                account = Account.objects.get(phone_e164=e164)
                created = False
        if account.status in (Account.Status.DEACTIVATED, Account.Status.DELETED):
            raise Forbidden("This account is unavailable.")
        had_devices = Device.objects.filter(account=account).exists()
        device_obj, is_new_device = (None, False)
        if device:
            device_obj, is_new_device = _touch_device(account=account, **device)
        session, refresh = _create_session(account=account, device=device_obj)
        account.last_seen_at = timezone.now()
        account.save(update_fields=["last_seen_at", "updated_at"])
        if device_obj and is_new_device and had_devices:
            _alert_new_device(account, device_obj)
    return AuthResult(
        access=tokens.issue_access_token(account_id=account.id, session_id=session.id),
        refresh=refresh,
        account=account,
        session=session,
        created=created,
    )


def refresh_session(*, refresh_token: str) -> AuthResult:
    """Rotate a refresh token. Reuse of an already-rotated token revokes the entire chain."""
    h = tokens.hash_refresh_token(refresh_token)
    reuse_detected = False
    with transaction.atomic():
        old = (
            Session.objects.select_for_update()
            .select_related("account")
            .filter(refresh_token_hash=h)
            .first()
        )
        if old is None:
            raise Unauthenticated()
        now = timezone.now()
        if old.revoked_at is not None:
            if old.revoke_reason == Session.RevokeReason.ROTATED:
                Session.objects.filter(chain_id=old.chain_id, revoked_at__isnull=True).update(
                    revoked_at=now, revoke_reason=Session.RevokeReason.REUSE_DETECTED
                )
                reuse_detected = True
            else:
                raise Unauthenticated()
        elif old.expires_at <= now or old.account.status in ("deactivated", "deleted"):
            raise Unauthenticated()
        else:
            old.revoked_at, old.revoke_reason = now, Session.RevokeReason.ROTATED
            old.save(update_fields=["revoked_at", "revoke_reason", "updated_at"])
            new, refresh = _create_session(
                account=old.account, device=old.device, chain_id=old.chain_id, rotated_from=old
            )
    if reuse_detected:  # outside the atomic block so the revocation commits
        raise Unauthenticated()
    return AuthResult(
        access=tokens.issue_access_token(account_id=new.account_id, session_id=new.id),
        refresh=refresh,
        account=new.account,
        session=new,
        created=False,
    )


def revoke_session(*, session: Session, reason: str = Session.RevokeReason.USER) -> None:
    if session.revoked_at is None:
        session.revoked_at, session.revoke_reason = timezone.now(), reason
        session.save(update_fields=["revoked_at", "revoke_reason", "updated_at"])


def revoke_all_sessions(*, account: Account, reason: str = Session.RevokeReason.ENFORCEMENT) -> int:
    return Session.objects.filter(account=account, revoked_at__isnull=True).update(
        revoked_at=timezone.now(), revoke_reason=reason
    )


# ---------------------------------------------------------------- consents (MC-033)
def record_consent(
    *, account: Account, items: list[dict[str, Any]], source: str, ip: str | None = None
) -> list[ConsentRecord]:
    """Append one row per item (never updates). Latest row per kind is the current consent."""
    valid_kinds = set(ConsentRecord.Kind.values)
    rows = []
    for item in items:
        if item["kind"] not in valid_kinds:
            raise ValidationFailed(f"Unknown consent kind: {item['kind']}")
        rows.append(
            ConsentRecord(
                account=account,
                kind=item["kind"],
                version=item["version"],
                granted=bool(item["granted"]),
                source=source,
                ip_hmac=hmac_value(ip, purpose="ip") if ip else None,
            )
        )
    with transaction.atomic():
        created = ConsentRecord.objects.bulk_create(rows)
        for row in created:
            events.publish(
                ConsentChanged(account_id=account.id, kind=row.kind, granted=row.granted)
            )
        return created


def require_verification_consents(account: Account) -> None:
    if not selectors.has_required_verification_consents(account):
        raise ValidationFailed(
            "Please accept the Terms, Privacy Notice and data transfer notice first.",
            missing_consents=[
                k
                for k in selectors.REQUIRED_VERIFICATION_CONSENTS
                if not selectors.has_consent(account, k)
            ],
        )


# ---------------------------------------------------------------- devices (MC-034)
def _alert_new_device(account: Account, device: Device) -> None:
    events.publish(NewDeviceSignIn(account_id=account.id, device_id=device.id))
    transaction.on_commit(lambda: send_new_device_alert.delay(str(account.id), device.platform))


def _touch_device(
    *,
    account: Account,
    install_id: uuid.UUID,
    platform: str,
    app_version: str = "",
    os_version: str = "",
    push_token: str | None = None,
) -> tuple[Device, bool]:
    if platform not in Device.Platform.values:
        raise ValidationFailed("Unknown platform.")
    device, created = Device.objects.get_or_create(
        account=account,
        install_id=install_id,
        defaults={"platform": platform, "app_version": app_version, "os_version": os_version},
    )
    changed = ["last_seen_at", "updated_at"]
    for field, value in (
        ("platform", platform),
        ("app_version", app_version),
        ("os_version", os_version),
    ):
        if value and getattr(device, field) != value:
            setattr(device, field, value)
            changed.append(field)
    if push_token is not None and device.push_token != push_token:
        # A push token belongs to exactly one device per platform: it moves if the phone changes hands.
        Device.objects.filter(platform=platform, push_token=push_token).exclude(
            id=device.id
        ).update(push_token=None)
        device.push_token = push_token
        changed.append("push_token")
    device.save(update_fields=changed)
    return device, created


def register_device(
    *,
    account: Account,
    install_id: uuid.UUID,
    platform: str,
    push_token: str | None,
    app_version: str = "",
    os_version: str = "",
) -> Device:
    """Upsert the device and its push token. A device that is new to an account that already has
    others triggers the new-device alert."""
    with transaction.atomic():
        had_devices = Device.objects.filter(account=account).exists()
        device, created = _touch_device(
            account=account,
            install_id=install_id,
            platform=platform,
            app_version=app_version,
            os_version=os_version,
            push_token=push_token,
        )
        if created and had_devices:
            _alert_new_device(account, device)
    return device


# ---------------------------------------------------------------- status
def set_status(*, account: Account, status: str) -> None:
    """Change account status (callers: verification, safety, privacy). Suspension also signs the
    user out everywhere."""
    if status not in Account.Status.values:
        raise ValidationFailed("Unknown status.")
    with transaction.atomic():
        account.status = status
        account.save(update_fields=["status", "updated_at"])
        if status in (Account.Status.SUSPENDED, Account.Status.DEACTIVATED, Account.Status.DELETED):
            revoke_all_sessions(account=account, reason=Session.RevokeReason.ACCOUNT)


def hard_delete_account(*, account: Account) -> None:
    """Erase the account row and everything cascading from it (called by the privacy deletion job after
    the grace period; retained items keep no FK to the account). Consent rows are append-only except here."""
    from django.db import connection

    with transaction.atomic():
        with connection.cursor() as cur:
            cur.execute("SET LOCAL mc.purge_consents = 'on'")
        account.delete()


def clear_push_token(*, platform: str, token: str) -> int:
    """Prune a token the push provider reported invalid."""
    return Device.objects.filter(platform=platform, push_token=token).update(push_token=None)


# ---------------------------------------------------------------- re-authentication (sensitive actions)
def start_reauth(*, account: Account, ip: str) -> None:
    """Send a fresh OTP to the account's own phone for a sensitive action (deletion). Same limits as login."""
    ratelimit.hit(
        f"otp:send:ip:{hmac_value(ip, purpose='ip').hex()[:32]}",
        limit=settings.OTP_SENDS_PER_IP_PER_HOUR,
        window_seconds=HOUR,
    )
    ratelimit.hit(
        f"otp:send:phone:{hmac_value(account.phone_e164, purpose='phone').hex()}",
        limit=settings.OTP_SENDS_PER_PHONE_PER_HOUR,
        window_seconds=HOUR,
    )
    code = f"{secrets.randbelow(10**6):06d}"
    r = get_redis()
    key = _otp_key("reauth", account.phone_e164)
    pipe = r.pipeline()
    pipe.delete(key)
    pipe.hset(key, mapping={"code_hash": _code_hash(account.phone_e164, code), "attempts": 0})
    pipe.expire(key, settings.OTP_TTL_MINUTES * 60)
    pipe.execute()
    get_sms_provider().send(
        to_e164=account.phone_e164,
        body=f"Your Marriage Connect confirmation code is {code}. Never share it.",
    )


def consume_reauth_otp(*, account: Account, code: str) -> bool:
    try:
        _check_otp(e164=account.phone_e164, code=code, purpose="reauth")
    except ValidationFailed:
        return False
    return True


def purge_dead_sessions(*, before) -> int:  # type: ignore[no-untyped-def]
    """Retention: sessions revoked or expired before `before` (90 days)."""
    from django.db.models import Q

    deleted, _ = Session.objects.filter(
        Q(revoked_at__lt=before) | Q(expires_at__lt=before)
    ).delete()
    return deleted

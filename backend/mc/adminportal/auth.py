"""Staff authentication (MC-113): SSO for pre-provisioned staff only → mandatory TOTP → server-side session with a
signed HttpOnly SameSite=Strict cookie. Sensitive actions need a step-up (fresh TOTP) within STAFF_REAUTH_MINUTES."""

import contextlib
import hashlib
import ipaddress
import secrets
from datetime import timedelta

from django.conf import settings
from django.core import signing
from django.http import HttpRequest, HttpResponse
from django.utils import timezone

from mc.common import ratelimit
from mc.common.crypto import hmac_value
from mc.common.errors import Forbidden, RateLimited, Unauthenticated, ValidationFailed

from . import totp
from .models import StaffSession, StaffUser
from .providers.sso import get_sso, new_state

SALT = "mc.adminportal.cookie"
STATE_COOKIE = "mc_admin_sso"
MFA_MAX_FAILURES = 5  # wrong TOTP codes per staff member per lock window
MFA_LOCK_SECONDS = 15 * 60


def safe_next(raw: str | None) -> str:
    """A same-site absolute path, else "/". Rejects scheme/host forms, `//`, and backslash/control-character
    tricks that browsers normalise into `//host`."""
    if not raw or not raw.startswith("/") or raw.startswith("//"):
        return "/"
    if "\\" in raw or any(ord(ch) < 0x20 or ord(ch) == 0x7F for ch in raw):
        return "/"
    return raw


def ip_allowed(ip: str) -> bool:
    nets = settings.ADMIN_IP_ALLOWLIST
    if not nets:
        return True
    try:
        addr = ipaddress.ip_address(ip)
        return any(addr in ipaddress.ip_network(n, strict=False) for n in nets)
    except ValueError:
        return False


def _hash(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


# ------------------------------------------------------------------------------------------------ SSO login
def begin_sso(*, redirect_uri: str) -> tuple[str, str, str]:
    """→ (authorization url, state, nonce). State+nonce are kept in a signed short-lived cookie."""
    state, nonce = new_state(), secrets.token_urlsafe(16)
    return (
        get_sso().authorization_url(state=state, nonce=nonce, redirect_uri=redirect_uri),
        state,
        nonce,
    )


def complete_sso(
    *, code: str, state: str, cookie_state: str, redirect_uri: str, ip: str
) -> tuple[StaffUser, str]:
    """Validate the callback and return (staff, raw session token). Unknown / inactive / wrong-domain identities
    get the same generic failure (no account enumeration)."""
    try:
        data = signing.loads(cookie_state, salt=SALT + ".state", max_age=600)
    except signing.BadSignature:
        raise Unauthenticated() from None
    if not secrets.compare_digest(str(data.get("state", "")), state):
        raise Unauthenticated()
    ident = get_sso().exchange(
        code=code, redirect_uri=redirect_uri, nonce=str(data.get("nonce", ""))
    )
    domain = ident.email.rsplit("@", 1)[-1]
    if not ident.email_verified or domain not in settings.STAFF_ALLOWED_EMAIL_DOMAINS:
        raise Unauthenticated()
    staff = StaffUser.objects.filter(email__iexact=ident.email, active=True).first()
    if staff is None or (staff.sso_subject and staff.sso_subject != ident.subject):
        raise Unauthenticated()
    if not staff.sso_subject:
        staff.sso_subject = ident.subject
        staff.save(update_fields=["sso_subject", "updated_at"])
    return staff, _new_session(staff, ip)


def sign_state(state: str, nonce: str) -> str:
    return signing.dumps({"state": state, "nonce": nonce}, salt=SALT + ".state")


def _new_session(staff: StaffUser, ip: str) -> str:
    token = secrets.token_urlsafe(32)
    StaffSession.objects.create(
        staff=staff,
        token_hash=_hash(token),
        expires_at=timezone.now() + timedelta(hours=settings.STAFF_SESSION_HOURS),
        ip_hmac=hmac_value(ip, purpose="ip"),
    )
    return token


# ------------------------------------------------------------------------------------------------ TOTP
def enrol_secret(staff: StaffUser) -> str:
    """The pending secret shown at enrolment (stored encrypted; becomes active when the first code verifies)."""
    if staff.totp_enrolled_at:
        raise Forbidden("MFA is already set up.")
    if not staff.totp_secret:
        staff.totp_secret = totp.new_secret()
        staff.save(update_fields=["totp_secret", "updated_at"])
    return str(staff.totp_secret)


def verify_mfa(session: StaffSession, code: str) -> None:
    """First-factor session → MFA-verified (also enrols on first success). Replay-safe."""
    staff = session.staff
    if not staff.totp_secret:
        raise Forbidden("Set up MFA first.")
    bucket = f"staff:totp:{staff.id}"
    if not ratelimit.check_only(bucket, limit=MFA_MAX_FAILURES):
        raise RateLimited(retry_after=MFA_LOCK_SECONDS)
    step = totp.verify(str(staff.totp_secret), code.strip(), last_step=staff.totp_last_step)
    if step is None:
        # a 6-digit code must not be brute-forceable: lock the staff member out after repeated misses
        with contextlib.suppress(RateLimited):
            ratelimit.hit(bucket, limit=MFA_MAX_FAILURES, window_seconds=MFA_LOCK_SECONDS)
        raise ValidationFailed("That code didn't work.")
    now = timezone.now()
    staff.totp_last_step = step
    staff.last_login_at = now
    if not staff.totp_enrolled_at:
        staff.totp_enrolled_at = now
    staff.save(update_fields=["totp_last_step", "last_login_at", "totp_enrolled_at", "updated_at"])
    session.mfa_verified_at = session.reauth_at = now
    session.save(update_fields=["mfa_verified_at", "reauth_at", "updated_at"])


def step_up(session: StaffSession, code: str) -> None:
    verify_mfa(session, code)  # same check; refreshes reauth_at


# ------------------------------------------------------------------------------------------------ session
def load_session(token: str | None) -> StaffSession | None:
    if not token:
        return None
    s = (
        StaffSession.objects.select_related("staff")
        .filter(token_hash=_hash(token), revoked_at__isnull=True, expires_at__gt=timezone.now())
        .first()
    )
    return s if s and s.staff.active else None


def recently_reauthed(session: StaffSession) -> bool:
    return bool(
        session.reauth_at
        and session.reauth_at > timezone.now() - timedelta(minutes=settings.STAFF_REAUTH_MINUTES)
    )


def logout(session: StaffSession) -> None:
    session.revoked_at = timezone.now()
    session.save(update_fields=["revoked_at", "updated_at"])


def set_cookie(response: HttpResponse, token: str) -> None:
    response.set_cookie(
        settings.STAFF_COOKIE, signing.dumps(token, salt=SALT), max_age=settings.STAFF_SESSION_HOURS * 3600,
        httponly=True, samesite="Strict", secure=settings.SESSION_COOKIE_SECURE,
    )  # fmt: skip


def read_cookie(request: HttpRequest) -> str | None:
    raw = request.COOKIES.get(settings.STAFF_COOKIE)
    if not raw:
        return None
    try:
        return str(signing.loads(raw, salt=SALT, max_age=settings.STAFF_SESSION_HOURS * 3600))
    except signing.BadSignature:
        return None

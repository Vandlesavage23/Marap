"""Pay-host member session: the normal access/refresh pair, kept in one signed HttpOnly SameSite=Strict cookie
(never in JS-readable storage). Access tokens are refreshed transparently; reuse detection still applies."""

from django.conf import settings
from django.core import signing
from django.http import HttpRequest, HttpResponse

from mc.accounts import selectors as account_selectors
from mc.accounts import services as account_services
from mc.common.errors import DomainError

COOKIE = "mc_pay"
SALT = "mc.webcheckout.cookie"
MAX_AGE = 3600 * 8


def set_tokens(response: HttpResponse, *, access: str, refresh: str) -> None:
    response.set_cookie(
        COOKIE, signing.dumps({"a": access, "r": refresh}, salt=SALT), max_age=MAX_AGE,
        httponly=True, samesite="Strict", secure=settings.SESSION_COOKIE_SECURE,
    )  # fmt: skip


def clear(response: HttpResponse) -> None:
    response.delete_cookie(COOKIE)


def resolve(request: HttpRequest):  # type: ignore[no-untyped-def]
    """→ (account, refreshed_tokens | None) or (None, None). A refresh failure signs the browser out."""
    raw = request.COOKIES.get(COOKIE)
    if not raw:
        return None, None
    try:
        data = signing.loads(raw, salt=SALT, max_age=MAX_AGE)
        access, refresh = str(data["a"]), str(data["r"])
    except (signing.BadSignature, KeyError):
        return None, None
    try:
        account, _ = account_selectors.authenticate_access_token(access)
        return account, None
    except DomainError as exc:
        if exc.code != "token_expired":
            return None, None
    try:
        res = account_services.refresh_session(refresh_token=refresh)
    except DomainError:
        return None, None
    return res.account, (res.access, res.refresh)

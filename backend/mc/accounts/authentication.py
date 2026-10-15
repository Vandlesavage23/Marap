from django.utils import timezone
from rest_framework.authentication import BaseAuthentication, get_authorization_header

from mc.common.errors import Unauthenticated

from .models import Account, Session
from .tokens import decode_access_token

REJECTED_STATUSES = {Account.Status.DEACTIVATED, Account.Status.DELETED}


class JWTAuthentication(BaseAuthentication):
    """`Authorization: Bearer <access_jwt>`. The session must still be live (not revoked/expired), so
    logout, 'revoke device' and enforcement take effect before the 15-minute token expires."""

    def authenticate_header(self, request) -> str:  # type: ignore[no-untyped-def]
        return "Bearer"

    def authenticate(self, request):  # type: ignore[no-untyped-def]
        header = get_authorization_header(request).split()
        if not header or header[0].lower() != b"bearer":
            return None
        if len(header) != 2:
            raise Unauthenticated()
        claims = decode_access_token(header[1].decode())
        session = (
            Session.objects.select_related("account")
            .filter(id=claims["sid"], account_id=claims["sub"])
            .first()
        )
        now = timezone.now()
        if session is None or session.revoked_at or session.expires_at <= now:
            raise Unauthenticated()
        account = session.account
        if account.status in REJECTED_STATUSES:
            raise Unauthenticated()
        request.session_obj = session
        return account, claims

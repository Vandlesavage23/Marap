import uuid
from datetime import datetime

from django.db.models import QuerySet
from django.utils import timezone

from .models import Account, ConsentRecord, Session

REQUIRED_VERIFICATION_CONSENTS = (
    ConsentRecord.Kind.TERMS,
    ConsentRecord.Kind.PRIVACY,
    ConsentRecord.Kind.DATA_TRANSFER,
)


def get_account(account_id: uuid.UUID) -> Account | None:
    return Account.objects.filter(id=account_id).first()


def get_account_by_phone(phone_e164: str) -> Account | None:
    return Account.objects.filter(phone_e164=phone_e164).first()


def active_sessions(account: Account, *, now: datetime | None = None) -> QuerySet[Session]:
    now = now or timezone.now()
    return (
        Session.objects.filter(account=account, revoked_at__isnull=True, expires_at__gt=now)
        .select_related("device")
        .order_by("-id")
    )


def current_consents(account: Account) -> dict[str, ConsentRecord]:
    """Latest row per kind."""
    latest: dict[str, ConsentRecord] = {}
    for rec in ConsentRecord.objects.filter(account=account).order_by("id"):
        latest[rec.kind] = rec
    return latest


def has_consent(account: Account, kind: str) -> bool:
    rec = (
        ConsentRecord.objects.filter(account=account, kind=kind)
        .order_by("-id")
        .only("granted")
        .first()
    )
    return bool(rec and rec.granted)


def has_required_verification_consents(account: Account) -> bool:
    return all(has_consent(account, k) for k in REQUIRED_VERIFICATION_CONSENTS)


def lock_account(account_id: uuid.UUID) -> Account:
    """SELECT ... FOR UPDATE (call inside a transaction) to serialise per-account operations."""
    return Account.objects.select_for_update().get(id=account_id)


def push_targets(account_id: uuid.UUID) -> list[tuple[str, str]]:
    """`[(platform, push_token)]` for the account's devices that have a token."""
    from .models import Device

    rows = Device.objects.filter(account_id=account_id, push_token__isnull=False).values_list(
        "platform", "push_token"
    )
    return [(platform, token) for platform, token in rows if token]


def authenticate_access_token(token: str):  # type: ignore[no-untyped-def]
    """`(account, session)` for a valid access token with a live session, else raises Unauthenticated/TokenExpired."""
    from mc.common.errors import Unauthenticated

    from .authentication import authenticate_token

    account, session, _ = authenticate_token(token)
    if account.status == "suspended":  # restricted members get no realtime channel
        raise Unauthenticated()
    return account, session


def session_is_live(session_id: uuid.UUID) -> bool:
    from django.utils import timezone

    from .models import Session

    return (
        Session.objects.filter(
            id=session_id, revoked_at__isnull=True, expires_at__gt=timezone.now()
        )
        .exclude(account__status__in=["deactivated", "deleted", "suspended"])
        .exists()
    )


def verify_reauth_code(*, account: "Account", code: str) -> bool:
    """True if `code` is a live 'reauth' OTP for the account's phone (consumed on success)."""
    from . import services

    return services.consume_reauth_otp(account=account, code=code)


def export_for_account(account: Account) -> dict[str, object]:
    """Data-subject export: the member's own account data (never tokens or hashes)."""
    return {
        "id": str(account.id),
        "phone": account.phone_e164,
        "email": account.email,
        "email_verified": account.email_verified_at is not None,
        "status": account.status,
        "locale": account.locale,
        "created_at": account.created_at.isoformat(),
        "consents": [
            {
                "kind": c.kind,
                "version": c.version,
                "granted": c.granted,
                "source": c.source,
                "at": c.created_at.isoformat(),
            }
            for c in ConsentRecord.objects.filter(account=account).order_by("id")
        ],
        "devices": [
            {
                "platform": d.platform,
                "app_version": d.app_version,
                "os_version": d.os_version,
                "first_seen_at": d.first_seen_at.isoformat(),
            }
            for d in account.devices.all()
        ],
    }

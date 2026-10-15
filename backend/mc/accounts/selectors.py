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
    from .authentication import authenticate_token

    account, session, _ = authenticate_token(token)
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

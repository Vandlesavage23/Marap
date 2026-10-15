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

import uuid
from datetime import date, timedelta
from typing import TYPE_CHECKING

from django.utils import timezone

from .models import VerificationAttempt

if TYPE_CHECKING:
    from mc.accounts.models import Account


def latest_attempt(account: "Account") -> VerificationAttempt | None:
    return VerificationAttempt.objects.filter(account=account).order_by("-id").first()


def latest_status(account: "Account") -> dict[str, str | None]:
    """`status` is one of not_started | created | submitted | passed | failed | needs_review | error | expired."""
    att = latest_attempt(account)
    if att is None:
        return {"status": "not_started", "reason": None}
    return {"status": att.status, "reason": att.reason_code or None}


def is_verified_adult(account: "Account") -> bool:
    return VerificationAttempt.objects.filter(account=account, status="passed").exists()


def passed_attempt(account: "Account") -> VerificationAttempt | None:
    return VerificationAttempt.objects.filter(account=account, status="passed").first()


def verified_date_of_birth(account: "Account") -> date | None:
    att = passed_attempt(account)
    return att.date_of_birth if att else None


def identity_hmac(account: "Account") -> bytes | None:
    """HMAC of the verified ID number (one human → one trial / one account)."""
    att = passed_attempt(account)
    return bytes(att.id_number_hmac) if att and att.id_number_hmac else None


def attempts_in_last_24h(account: "Account") -> int:
    since = timezone.now() - timedelta(hours=24)
    return VerificationAttempt.objects.filter(account=account, created_at__gte=since).count()


def get_attempt(attempt_id: uuid.UUID) -> VerificationAttempt | None:
    return VerificationAttempt.objects.filter(id=attempt_id).first()


def export_for_account(account) -> list[dict[str, object]]:  # type: ignore[no-untyped-def]
    return [
        {
            "status": a.status,
            "reason": a.reason_code or None,
            "date_of_birth": a.date_of_birth.isoformat() if a.date_of_birth else None,
            "at": a.created_at.isoformat(),
        }
        for a in VerificationAttempt.objects.filter(account=account).order_by("id")
    ]

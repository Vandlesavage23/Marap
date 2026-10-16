"""Persisting the nightly reconciliation report for the staff portal (Bible §15 "payments reconciliation")."""

from datetime import datetime, timedelta
from typing import Any

from django.utils import timezone

from .models import ReconciliationReport

KEEP = 90  # nights of history
MAX_STORED_MISMATCHES = (
    500  # the count is always exact; the list is capped so a bad night can't bloat a row
)


def save_report(report: dict[str, Any]) -> ReconciliationReport:
    mismatches = list(report.get("mismatches", []))
    row = ReconciliationReport.objects.create(
        generated_at=datetime.fromisoformat(report["generated_at"]),
        window_hours=report["window_hours"],
        purchases_active=report["purchases_active"],
        events_received=report["events_received"],
        mismatch_count=len(mismatches),
        mismatches=mismatches[:MAX_STORED_MISMATCHES],
    )
    stale = ReconciliationReport.objects.order_by("-generated_at", "-id").values_list(
        "id", flat=True
    )[KEEP:]
    ReconciliationReport.objects.filter(id__in=list(stale)).delete()
    return row


def latest() -> ReconciliationReport | None:
    return ReconciliationReport.objects.order_by("-generated_at", "-id").first()


def history(limit: int = 14) -> list[ReconciliationReport]:
    return list(ReconciliationReport.objects.order_by("-generated_at", "-id")[:limit])


def is_stale(
    row: ReconciliationReport | None, *, now: datetime | None = None, hours: int = 36
) -> bool:
    """No report yet, or the nightly job hasn't run for over `hours` (it runs every 24 h)."""
    if row is None:
        return True
    return (now or timezone.now()) - row.generated_at > timedelta(hours=hours)

import uuid
from dataclasses import dataclass
from datetime import datetime, timedelta

from django.conf import settings
from django.db.models import Q, QuerySet

from mc.common.pagination import Page, paginate
from mc.common.timeutil import next_kampala_midnight, start_of_kampala_day
from mc.safety import selectors as safety_selectors

from .models import Interest


def pending_counterpart_ids(account_id: uuid.UUID) -> set[uuid.UUID]:
    """Accounts with a pending interest to or from `account_id` (excluded from discovery)."""
    rows = (
        Interest.objects.filter(status="pending")
        .filter(Q(sender_id=account_id) | Q(recipient_id=account_id))
        .values_list("sender_id", "recipient_id")
    )
    return {b if a == account_id else a for a, b in rows}


@dataclass(frozen=True)
class Allowance:
    """How many interests the account may still send. `period` is `rolling_7_days` (free/expired accounts) or `day`
    (trial/member). `resets_at` is when a slot next frees up (None when nothing has been used)."""

    limit: int
    used: int
    resets_at: datetime | None
    period: str

    @property
    def exhausted(self) -> bool:
        return self.used >= self.limit


def allowance(account_id: uuid.UUID, *, state: str, now: datetime) -> Allowance:
    """The interest allowance that applies to an account in entitlement `state` (`none|trial|member|expired`).
    Counts every interest the account created (replays return the stored one and never add a row; accepting an
    interest that is already waiting for you creates none either)."""
    mine = Interest.objects.filter(sender_id=account_id)
    if state in ("trial", "member"):
        used = mine.filter(created_at__gte=start_of_kampala_day(now)).count()
        limit = (
            settings.INTEREST_DAILY_LIMIT_MEMBER
            if state == "member"
            else settings.INTEREST_DAILY_LIMIT_TRIAL
        )
        return Allowance(limit, used, next_kampala_midnight(now) if used else None, "day")
    window = timedelta(days=settings.FREE_INTERESTS_WINDOW_DAYS)
    in_window = mine.filter(created_at__gt=now - window)  # an interest leaves the window at created_at + 7 d
    limit = settings.FREE_INTERESTS_PER_WEEK
    stamps = list(in_window.order_by("created_at").values_list("created_at", flat=True))
    used = len(stamps)
    resets_at = stamps[min(max(used - limit, 0), used - 1)] + window if stamps else None
    return Allowance(limit, used, resets_at, "rolling_7_days")


def received(account_id: uuid.UUID, *, cursor: str | None, limit: int) -> Page[Interest]:
    """Interests waiting for `account_id` (pending, unexpired), newest first; blocked senders never appear."""
    from django.utils import timezone

    blocked = safety_selectors.blocked_either_way_ids(account_id)
    qs: QuerySet[Interest] = (
        Interest.objects.filter(
            recipient_id=account_id, status="pending", expires_at__gt=timezone.now()
        )
        .exclude(sender_id__in=blocked)
        .select_related("snapshot")
    )
    return paginate(qs, cursor=cursor, limit=limit)


def sent(account_id: uuid.UUID, *, cursor: str | None, limit: int) -> Page[Interest]:
    blocked = safety_selectors.blocked_either_way_ids(account_id)
    qs = Interest.objects.filter(sender_id=account_id).exclude(recipient_id__in=blocked)
    return paginate(qs, cursor=cursor, limit=limit)


def sender_visible_status(interest: Interest) -> str:
    """What the *sender* sees. They are never told about a pass: it reads `pending` until it expires."""
    if interest.status == Interest.Status.PASSED:
        from django.utils import timezone

        return "pending" if interest.expires_at > timezone.now() else "expired"
    if interest.status == Interest.Status.CANCELLED:
        return "expired"
    return str(interest.status)


def get_for_recipient(interest_id: uuid.UUID, account_id: uuid.UUID) -> Interest | None:
    return (
        Interest.objects.filter(id=interest_id, recipient_id=account_id)
        .select_related("snapshot")
        .first()
    )


def evidence_for_report(
    *, interest_id: uuid.UUID, reporter_id: uuid.UUID, subject_id: uuid.UUID
) -> dict[str, object] | None:
    """What the subject sent: only for interests between exactly these two members."""
    i = (
        Interest.objects.select_related("snapshot")
        .filter(id=interest_id)
        .filter(
            Q(sender_id=subject_id, recipient_id=reporter_id)
            | Q(sender_id=reporter_id, recipient_id=subject_id)
        )
        .first()
    )
    if i is None or i.snapshot is None:
        return None
    return {
        "interest_id": str(i.id),
        "from": "subject" if i.sender_id == subject_id else "reporter",
        "display_name": i.snapshot.display_name,
        "text": i.snapshot.text,
    }


def export_for_account(account) -> dict[str, list[dict[str, object]]]:  # type: ignore[no-untyped-def]
    """Interests the member sent (with the text they sent) and received (the text addressed to them)."""
    snap = lambda i: i.snapshot.text if i.snapshot else None  # noqa: E731
    return {
        "sent": [
            {"status": i.status, "sent_at": i.created_at.isoformat(), "text_sent": snap(i)}
            for i in Interest.objects.filter(sender=account).select_related("snapshot")
        ],
        "received": [
            {
                "status": i.status,
                "received_at": i.created_at.isoformat(),
                "from_display_name": i.snapshot.display_name if i.snapshot else None,
                "text_received": snap(i),
            }
            for i in Interest.objects.filter(recipient=account).select_related("snapshot")
        ],
    }


def funnel_first_interest_count(*, start: datetime, end: datetime) -> int | None:
    """Dashboard funnel, stage 4: accounts registered in `[start, end)` that have sent at least one interest."""
    from mc.common.aggregates import suppress

    n = (
        Interest.objects.filter(sender__created_at__gte=start, sender__created_at__lt=end)
        .values("sender_id")
        .distinct()
        .count()
    )
    return suppress(n)

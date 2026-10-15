import uuid

from django.db.models import Q, QuerySet

from mc.common.pagination import Page, paginate
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

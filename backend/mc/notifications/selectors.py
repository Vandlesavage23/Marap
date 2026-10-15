import uuid

from mc.common.pagination import Page, paginate
from mc.safety import selectors as safety_selectors

from .models import Notification


def inbox(account_id: uuid.UUID, *, cursor: str | None, limit: int) -> Page[Notification]:
    blocked = safety_selectors.blocked_either_way_ids(account_id)
    qs = Notification.objects.filter(account_id=account_id).exclude(counterpart_id__in=blocked)
    return paginate(qs, cursor=cursor, limit=limit)


def unread_count(account_id: uuid.UUID) -> int:
    return Notification.objects.filter(account_id=account_id, read_at__isnull=True).count()


def export_for_account(account) -> list[dict[str, object]]:  # type: ignore[no-untyped-def]
    return [
        {
            "type": n.type,
            "payload": n.payload,
            "at": n.created_at.isoformat(),
            "read": n.read_at is not None,
        }
        for n in Notification.objects.filter(account=account).order_by("id")
    ]

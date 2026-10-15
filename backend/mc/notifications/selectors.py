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

import uuid
from typing import Any

from django.conf import settings
from django.db import transaction
from django.utils import timezone

from mc.accounts import selectors as account_selectors
from mc.common.errors import ValidationFailed
from mc.common.redis import get_redis
from mc.safety import selectors as safety_selectors

from .catalog import CATALOG
from .models import Notification


def notify(
    *,
    account_id: uuid.UUID,
    type: str,
    payload: dict[str, Any] | None = None,
    counterpart_id: uuid.UUID | None = None,
    debounce_key: str | None = None,
) -> Notification | None:
    """Create the inbox entry (if the type has one) and enqueue a generic push. Skipped entirely when the
    other member is blocked either way (CLAUDE.md rule 5). Payload values must be ids/short codes only."""
    spec = CATALOG[type]
    if counterpart_id and safety_selectors.is_blocked_either_way(account_id, counterpart_id):
        return None
    data = {k: str(v) for k, v in (payload or {}).items()}
    entry = None
    if spec["inbox"]:
        entry = Notification.objects.create(
            account_id=account_id, type=type, payload=data, counterpart_id=counterpart_id
        )
    if debounce_key and not get_redis().set(
        f"push:debounce:{type}:{debounce_key}", "1", nx=True, ex=settings.PUSH_DEBOUNCE_SECONDS
    ):
        return entry  # a push for this conversation went out moments ago
    from .tasks import send_push

    send_push.delay(str(account_id), type, data)
    return entry


def mark_read(*, account_id: uuid.UUID, ids: list[uuid.UUID] | None) -> int:
    qs = Notification.objects.filter(account_id=account_id, read_at__isnull=True)
    if ids is not None:
        if len(ids) > 200:
            raise ValidationFailed("Too many ids.")
        qs = qs.filter(id__in=ids)
    return qs.update(read_at=timezone.now(), updated_at=timezone.now())


def purge_between(*, a: uuid.UUID, b: uuid.UUID) -> int:
    """Block: remove every inbox entry about the other member (called inside the block transaction)."""
    with transaction.atomic():
        first = Notification.objects.filter(account_id=a, counterpart_id=b).delete()[0]
        second = Notification.objects.filter(account_id=b, counterpart_id=a).delete()[0]
    return first + second


def push_body(type: str) -> str:
    return str(CATALOG[type]["body"])


def has_push_target(account_id: uuid.UUID) -> bool:
    return bool(account_selectors.push_targets(account_id))

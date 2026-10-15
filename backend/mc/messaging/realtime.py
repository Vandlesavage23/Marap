"""Server → socket fan-out. Runs from after-commit event handlers (sync) via the channel layer."""

import uuid
from typing import Any

from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer

from .consumers import group_name


def send_to_account(account_id: uuid.UUID, event: dict[str, Any]) -> None:
    layer = get_channel_layer()
    if layer is None:  # pragma: no cover - no channel layer configured
        return
    async_to_sync(layer.group_send)(group_name(account_id), event)

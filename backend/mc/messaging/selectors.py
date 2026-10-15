import uuid
from typing import TYPE_CHECKING

from django.db.models import QuerySet

from mc.common.pagination import Page, paginate

from .models import Message

if TYPE_CHECKING:
    from mc.accounts.models import Account
    from mc.matches.models import Match


def history(match: "Match", *, before: str | None, limit: int) -> Page[Message]:
    """Newest first. `before` is the opaque cursor from the previous page's `next_cursor`."""
    qs: QuerySet[Message] = Message.objects.filter(match=match).select_related("media")
    return paginate(qs, cursor=before, limit=limit)


def get_message(message_id: uuid.UUID) -> Message | None:
    return Message.objects.select_related("media", "match").filter(id=message_id).first()


def message_payload(msg: Message, viewer: "Account") -> dict[str, object]:
    """One message as `viewer` sees it. Media URLs are signed per viewer (never public)."""
    from mc.media import selectors as media_selectors

    media = None
    if msg.media is not None and msg.media.status == "ready":
        media = {
            "id": str(msg.media.id),
            "url": media_selectors.signed_url(msg.media, viewer),
            "w": msg.media.width,
            "h": msg.media.height,
            "duration_ms": msg.media.duration_ms,
        }
    mine = msg.sender_id == viewer.id
    return {
        "id": str(msg.id),
        "match_id": str(msg.match_id),
        "client_msg_id": str(msg.client_msg_id) if mine and msg.client_msg_id else None,
        "sender": "system" if msg.kind == "system" else ("me" if mine else "them"),
        "kind": msg.kind,
        "body": None if msg.deleted_placeholder else msg.body,
        "deleted": msg.deleted_placeholder,
        "media": media,
        "created_at": msg.created_at,
        "delivered_at": msg.delivered_at,
        "read_at": msg.read_at,
        # the flag is a safety tip for the *recipient*; the sender is never told they were flagged
        "safety_tip": bool(msg.moderation_flag) and not mine,
    }

import uuid
from typing import TYPE_CHECKING, Any

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


def evidence_for_report(
    *, message_id: uuid.UUID, reporter_id: uuid.UUID, subject_id: uuid.UUID, prior: int
) -> list[dict[str, object]] | None:
    """The reported message (sent by `subject`) plus up to `prior` earlier messages in the same match, oldest
    first. None if the reporter isn't a member of that match or the subject didn't send it."""
    from mc.matches import selectors as match_selectors

    msg = (
        Message.objects.select_related("match").filter(id=message_id, sender_id=subject_id).first()
    )
    if msg is None or not match_selectors.is_match_member(msg.match, reporter_id):
        return None
    window = list(
        Message.objects.filter(match=msg.match, id__lt=msg.id)
        .exclude(kind="system")
        .order_by("-id")[:prior]
    )
    rows = [*reversed(window), msg]
    return [
        {
            "message_id": str(m.id),
            "from": "reporter" if m.sender_id == reporter_id else "subject",
            "kind": m.kind,
            "body": m.body,
            "media_id": str(m.media_id) if m.media_id else None,
            "sent_at": m.created_at.isoformat(),
            "reported": m.id == msg.id,
        }
        for m in rows
    ]


def export_for_account(account) -> list[dict[str, Any]]:  # type: ignore[no-untyped-def]
    """Every conversation the member was in: messages they sent and received, nothing else about the other person."""
    from mc.matches import selectors as match_selectors

    out = []
    for match in match_selectors.all_matches(account.id):
        msgs = Message.objects.filter(match=match).exclude(kind="system").order_by("id")
        out.append({
            "match_id": str(match.id), "status": match.status, "started_at": match.created_at.isoformat(),
            "messages": [
                {"from": "me" if m.sender_id == account.id else "them", "kind": m.kind, "body": None if m.deleted_placeholder else m.body,
                 "media_id": str(m.media_id) if m.media_id and m.sender_id == account.id else None, "sent_at": m.created_at.isoformat()}
                for m in msgs
            ],
        })  # fmt: skip
    return out

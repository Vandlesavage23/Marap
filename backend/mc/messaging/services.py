"""Messaging writes (Bible §9). Idempotent on `(sender, client_msg_id)`; policy-checked; event-driven."""

import uuid
from datetime import datetime
from typing import TYPE_CHECKING

from django.conf import settings
from django.db import IntegrityError, transaction
from django.utils import timezone

from mc.common import events, ratelimit
from mc.common.errors import Conflict, NotFound, ValidationFailed
from mc.matches import selectors as match_selectors
from mc.matches import services as match_services
from mc.media import selectors as media_selectors
from mc.safety import selectors as safety_selectors

from . import policies
from .events import MessageCreated, MessageRead
from .models import Message

if TYPE_CHECKING:
    from mc.accounts.models import Account

MEDIA_PURPOSE = {Message.Kind.IMAGE: "chat_image", Message.Kind.VOICE: "voice_note"}


def send_message(
    *,
    sender: "Account",
    match_id: uuid.UUID,
    client_msg_id: uuid.UUID,
    kind: str,
    body: str | None = None,
    media_id: uuid.UUID | None = None,
) -> tuple[Message, bool]:
    """Create a message. Returns `(message, created)`; a retry with the same `client_msg_id` returns the
    original row (`created=False`) — a timed-out send can be repeated safely (scenario 04)."""
    existing = Message.objects.filter(sender=sender, client_msg_id=client_msg_id).first()
    if existing is not None:
        if existing.match_id != match_id:
            raise Conflict("That client_msg_id was already used in another conversation.")
        return existing, False

    match = match_selectors.get_match(match_id)
    if match is None:
        raise NotFound()
    if kind not in (Message.Kind.TEXT, Message.Kind.IMAGE, Message.Kind.VOICE):
        raise ValidationFailed("Unknown message kind.")

    text = None
    media = None
    if kind == Message.Kind.TEXT:
        text = (body or "").strip()
        if not text or media_id is not None:
            raise ValidationFailed("Write a message first.")
        if len(text) > settings.MESSAGE_MAX_CHARS:
            raise ValidationFailed(
                f"Messages can be up to {settings.MESSAGE_MAX_CHARS} characters."
            )
    else:
        if body or media_id is None:
            raise ValidationFailed("Attach the file to send.")
        media = media_selectors.get_media(media_id)
        purpose = MEDIA_PURPOSE[Message.Kind(kind)]
        if (
            media is None
            or media.owner_id != sender.id
            or media.purpose != purpose
            or media.status != "ready"
            or (kind == Message.Kind.IMAGE and media.moderation != "approved")
        ):
            raise ValidationFailed("That file can't be sent.")
        if Message.objects.filter(media=media).exists():
            raise Conflict("That file was already sent.")

    ratelimit.hit(f"msg:{sender.id}", limit=settings.MESSAGES_PER_MINUTE, window_seconds=60)
    policies.check_can_send(sender, match, kind=kind, body=text)

    flag = safety_selectors.scam_flag(text) if text else None
    try:
        with transaction.atomic():
            msg = Message.objects.create(
                match=match,
                sender=sender,
                client_msg_id=client_msg_id,
                kind=kind,
                body=text,
                media=media,
                moderation_flag=flag,
            )
            match_services.record_participant_message(
                match_id=match.id, sender_id=sender.id, at=msg.created_at
            )
            events.publish(
                MessageCreated(
                    message_id=msg.id,
                    match_id=match.id,
                    sender_id=sender.id,
                    recipient_id=match_selectors.other_member(match, sender.id),
                    kind=kind,
                )
            )
    except IntegrityError:
        dup = Message.objects.filter(sender=sender, client_msg_id=client_msg_id).first()
        if dup is None:
            raise
        return dup, False
    return msg, True


def create_system_message(*, match_id: uuid.UUID, code: str) -> Message:
    """Server-generated line (e.g. `match_created`); the app renders `code` from its string catalog."""
    with transaction.atomic():
        msg = Message.objects.create(
            match_id=match_id, sender=None, kind=Message.Kind.SYSTEM, body=code
        )
        events.publish(
            MessageCreated(
                message_id=msg.id,
                match_id=match_id,
                sender_id=None,
                recipient_id=None,
                kind="system",
            )
        )
    return msg


def mark_read(*, account: "Account", match_id: uuid.UUID, up_to_message_id: uuid.UUID) -> int:
    """Mark the other member's messages up to `up_to_message_id` as read. Returns how many changed."""
    match = match_selectors.get_match(match_id)
    if match is None or not policies.can_read_conversation(account, match):
        raise NotFound()
    if not Message.objects.filter(id=up_to_message_id, match=match).exists():
        raise NotFound()
    with transaction.atomic():
        n = (
            Message.objects.filter(match=match, id__lte=up_to_message_id, read_at__isnull=True)
            .exclude(sender=account)
            .exclude(kind=Message.Kind.SYSTEM)
            .update(read_at=timezone.now(), updated_at=timezone.now())
        )
        if n:
            events.publish(
                MessageRead(
                    match_id=match.id, reader_id=account.id, up_to_message_id=up_to_message_id
                )
            )
    return n


def mark_delivered(*, message_id: uuid.UUID) -> None:
    Message.objects.filter(id=message_id, delivered_at__isnull=True).update(
        delivered_at=timezone.now()
    )


def hide_message(*, message_id: uuid.UUID) -> None:
    """Moderation: replace a message with a 'deleted' placeholder for both members."""
    Message.objects.filter(id=message_id).update(
        deleted_placeholder=True, updated_at=timezone.now()
    )


def scrub_sent_by(*, account_id: uuid.UUID) -> int:
    """Erasure: messages the member sent become 'message deleted' placeholders (body and media dropped)."""
    return Message.objects.filter(sender_id=account_id).update(
        body=None,
        media=None,
        deleted_placeholder=True,
        moderation_flag=None,
        updated_at=timezone.now(),
    )


def purge_ended_chats(*, before: datetime, hold_accounts: set[uuid.UUID]) -> int:
    """Retention: messages of matches that ended before `before` (90 days), unless either member is under a
    safety hold. The Match row stays (cool-off rules and the audit trail need it)."""
    n = 0
    for match_id, a, b in match_selectors.ended_matches_before(before):
        if a in hold_accounts or b in hold_accounts:
            continue
        deleted, _ = Message.objects.filter(match_id=match_id).delete()
        n += deleted
    return n

"""Messaging authorization predicates (Bible §9.1). Each returns None when allowed, or raises a domain
error via `check_*`; `can_*` helpers return booleans for list filtering."""

from datetime import timedelta
from typing import TYPE_CHECKING

from django.conf import settings
from django.utils import timezone

from mc.common.errors import (
    ContactDetailsBlocked,
    EntitlementRequired,
    NotFound,
    PhotoLocked,
    ValidationFailed,
)
from mc.entitlements import selectors as entitlement_selectors
from mc.matches import selectors as match_selectors
from mc.safety import selectors as safety_selectors

from .models import Message

if TYPE_CHECKING:
    from mc.accounts.models import Account
    from mc.matches.models import Match


def can_read_conversation(account: "Account", match: "Match") -> bool:
    """Member of an active (not unmatched/blocked) match with the read capability and no block."""
    return (
        match.status == "active"
        and match_selectors.is_match_member(match, account.id)
        and not safety_selectors.is_blocked_either_way(
            account.id, match_selectors.other_member(match, account.id)
        )
        and entitlement_selectors.has_capability(account, "read_conversations")
    )


def check_can_send(account: "Account", match: "Match", *, kind: str, body: str | None) -> None:
    """Raises if `account` may not send this message into `match` right now."""
    if not (match.status == "active" and match_selectors.is_match_member(match, account.id)):
        raise NotFound()
    other = match_selectors.other_member(match, account.id)
    if safety_selectors.is_blocked_either_way(account.id, other):
        raise NotFound()
    if not entitlement_selectors.has_capability(account, "send_message"):
        raise EntitlementRequired(
            "Sending messages needs an active trial or membership.", capability="send_message"
        )
    if kind == Message.Kind.IMAGE:
        sent = Message.objects.filter(match=match, sender=account).exclude(kind="system").count()
        theirs = Message.objects.filter(match=match, sender_id=other).exclude(kind="system").count()
        need = settings.PHOTO_UNLOCK_MIN_MESSAGES
        if sent < need or theirs < need:
            raise PhotoLocked(
                f"Photos unlock once you've each sent {need} messages.",
                needed=need,
                you_sent=sent,
                they_sent=theirs,
            )
    if kind == Message.Kind.VOICE and not settings.FEATURE_FLAGS_DEFAULT.get("voice_notes", True):
        raise ValidationFailed("Voice notes aren't available yet.")
    if kind == Message.Kind.TEXT and body:
        window = timedelta(hours=settings.CONTACT_BLOCK_HOURS)
        if timezone.now() - match.created_at < window:
            reason = safety_selectors.contact_details_reason(body)
            if reason:
                raise ContactDetailsBlocked(
                    "To keep everyone safe, phone numbers and links can't be shared in the first "
                    f"{settings.CONTACT_BLOCK_HOURS // 24} days of a match.",
                    reason=reason,
                    window_hours=settings.CONTACT_BLOCK_HOURS,
                )


def chat_media_policy(viewer: "Account", media) -> bool:  # type: ignore[no-untyped-def]
    """Media policy for chat images / voice notes: only the two members of the (active) match."""
    msg = Message.objects.select_related("match").filter(media=media).first()
    return bool(msg and can_read_conversation(viewer, msg.match))

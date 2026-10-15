"""Safety writes (Bible §10.8). Blocks are absolute and take effect in ONE transaction."""

import uuid
from typing import TYPE_CHECKING

from django.db import IntegrityError, transaction

from mc.common import events
from mc.common.errors import NotFound, ValidationFailed
from mc.interests import services as interest_services
from mc.matches import selectors as match_selectors
from mc.matches import services as match_services
from mc.notifications import services as notification_services
from mc.profiles import selectors as profile_selectors

from .events import UserBlocked
from .models import Block

if TYPE_CHECKING:
    from mc.accounts.models import Account


def block(*, blocker: "Account", blocked_id: uuid.UUID) -> Block:
    """Block `blocked_id` (an account id). In one transaction: create the Block, cancel pending interests
    both ways (deleting their snapshots), end the active match, purge inbox entries about each other.
    Discovery/profile/chat read the block at request time, so nothing else needs invalidating. The blocked
    user is not notified. Idempotent."""
    if blocked_id == blocker.id:
        raise ValidationFailed("You can't block yourself.")
    with transaction.atomic():
        try:
            with transaction.atomic():
                row, created = Block.objects.get_or_create(blocker=blocker, blocked_id=blocked_id)
        except IntegrityError:  # blocked account vanished concurrently
            raise NotFound() from None
        if created:
            interest_services.cancel_between(a=blocker.id, b=blocked_id)
            match = match_selectors.active_match_between(blocker.id, blocked_id)
            if match is not None:
                match_services.unmatch(match_id=match.id, by=blocker.id, reason="blocked")
            notification_services.purge_between(a=blocker.id, b=blocked_id)
            events.publish(UserBlocked(blocker_id=blocker.id, blocked_id=blocked_id))
    return row


def block_by_profile(*, blocker: "Account", profile_id: uuid.UUID) -> Block:
    """API entry: members know each other by profile id only."""
    account_id = profile_selectors.account_id_for_profile(profile_id)
    if account_id is None:
        raise NotFound()
    return block(blocker=blocker, blocked_id=account_id)


def unblock(*, blocker: "Account", profile_id: uuid.UUID) -> None:
    """Removes the Block row only — matches and interests are NOT restored (Bible §8.2)."""
    account_id = profile_selectors.account_id_for_profile(profile_id)
    if account_id is None:
        raise NotFound()
    Block.objects.filter(blocker=blocker, blocked_id=account_id).delete()

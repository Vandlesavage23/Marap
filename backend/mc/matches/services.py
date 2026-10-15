import uuid

from django.db import IntegrityError, transaction

from mc.common import events

from . import selectors
from .events import MatchCreated
from .models import Match


def create_match(*, account_x: uuid.UUID, account_y: uuid.UUID) -> tuple[Match, bool]:
    """Exactly one active match per pair. Returns `(match, created)`; concurrent callers converge on the
    same row (the partial unique index decides)."""
    ua, ub = selectors.ordered_pair(account_x, account_y)
    existing = selectors.active_match_between(ua, ub)
    if existing:
        return existing, False
    try:
        with transaction.atomic():
            match = Match.objects.create(user_a_id=ua, user_b_id=ub)
    except IntegrityError:
        found = selectors.active_match_between(ua, ub)
        if found is None:  # pragma: no cover - constraint failed for another reason
            raise
        return found, False
    events.publish(MatchCreated(match_id=match.id, user_a=ua, user_b=ub))
    return match, True


def unmatch(*, match_id: uuid.UUID, by: uuid.UUID, reason: str = "unmatched") -> Match:
    """End an active match (idempotent). Chat is hidden for both; the other member isn't told why."""
    from django.utils import timezone

    from .events import MatchEnded

    with transaction.atomic():
        match = Match.objects.select_for_update().filter(id=match_id).first()
        if match is None or by not in (match.user_a_id, match.user_b_id):
            from mc.common.errors import NotFound

            raise NotFound()
        if match.status != Match.Status.ACTIVE:
            return match
        match.status = Match.Status.BLOCKED if reason == "blocked" else Match.Status.UNMATCHED
        match.ended_at, match.ended_by_id = timezone.now(), by
        match.save(update_fields=["status", "ended_at", "ended_by", "updated_at"])
        events.publish(
            MatchEnded(
                match_id=match.id, user_a=match.user_a_id, user_b=match.user_b_id, reason=reason
            )
        )
    return match


def record_participant_message(*, match_id: uuid.UUID, sender_id: uuid.UUID, at) -> Match:  # type: ignore[no-untyped-def]
    """Called by messaging for every sent message. Sets `first_two_way_message_at` once BOTH participants
    have sent at least one message; never reset (Bible §10.5)."""
    with transaction.atomic():
        match = Match.objects.select_for_update().get(id=match_id)
        field = (
            "user_a_first_message_at" if sender_id == match.user_a_id else "user_b_first_message_at"
        )
        changed = []
        if getattr(match, field) is None:
            setattr(match, field, at)
            changed.append(field)
        if (
            match.first_two_way_message_at is None
            and match.user_a_first_message_at is not None
            and match.user_b_first_message_at is not None
        ):
            match.first_two_way_message_at = at
            changed.append("first_two_way_message_at")
        if changed:
            match.save(update_fields=[*changed, "updated_at"])
    return match

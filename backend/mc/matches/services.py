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

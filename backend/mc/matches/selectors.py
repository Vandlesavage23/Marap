import uuid

from django.db.models import Q, QuerySet

from .models import Match


def ordered_pair(a: uuid.UUID, b: uuid.UUID) -> tuple[uuid.UUID, uuid.UUID]:
    return (a, b) if a < b else (b, a)


def active_match_between(a: uuid.UUID, b: uuid.UUID) -> Match | None:
    ua, ub = ordered_pair(a, b)
    return Match.objects.filter(user_a_id=ua, user_b_id=ub, status=Match.Status.ACTIVE).first()


def active_matches(account_id: uuid.UUID) -> QuerySet[Match]:
    return Match.objects.filter(
        Q(user_a_id=account_id) | Q(user_b_id=account_id), status=Match.Status.ACTIVE
    )


def is_match_member(match: Match, account_id: uuid.UUID) -> bool:
    return account_id in (match.user_a_id, match.user_b_id)


def other_member(match: Match, account_id: uuid.UUID) -> uuid.UUID:
    return match.user_b_id if match.user_a_id == account_id else match.user_a_id


def get_match(match_id: uuid.UUID) -> Match | None:
    return Match.objects.filter(id=match_id).first()


def counterpart_ids(account_id: uuid.UUID, *, ended_since=None) -> set[uuid.UUID]:  # type: ignore[no-untyped-def]
    """Accounts matched with `account_id` now, plus (optionally) those whose match ended after `ended_since`.
    Used to keep matched / recently-unmatched people out of discovery and out of re-sent interests."""
    q = Q(status=Match.Status.ACTIVE)
    if ended_since is not None:
        q |= Q(ended_at__gte=ended_since)
    rows = (
        Match.objects.filter(Q(user_a_id=account_id) | Q(user_b_id=account_id))
        .filter(q)
        .values_list("user_a_id", "user_b_id")
    )
    return {b if a == account_id else a for a, b in rows}

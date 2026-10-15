import uuid

from django.db.models import Q

from .models import Block


def blocked_either_way_ids(account_id: uuid.UUID) -> set[uuid.UUID]:
    """Every account that blocked `account_id` or was blocked by them."""
    rows = Block.objects.filter(Q(blocker_id=account_id) | Q(blocked_id=account_id)).values_list(
        "blocker_id", "blocked_id"
    )
    out: set[uuid.UUID] = set()
    for a, b in rows:
        out.add(b if a == account_id else a)
    return out


def is_blocked_either_way(a: uuid.UUID, b: uuid.UUID) -> bool:
    return Block.objects.filter(
        Q(blocker_id=a, blocked_id=b) | Q(blocker_id=b, blocked_id=a)
    ).exists()


def contact_details_reason(text: str) -> str | None:
    """Reason a chat message must be blocked while the early-match contact window is open, else None."""
    from . import text_rules

    return text_rules.contact_reason(text)


def scam_flag(text: str) -> str | None:
    """Heuristic scam signal for a chat message (flag + safety tip for the recipient; never blocks)."""
    from . import text_rules

    return text_rules.scam_reason(text)

import uuid

from django.db.models import Q

from .models import Interest


def pending_counterpart_ids(account_id: uuid.UUID) -> set[uuid.UUID]:
    """Accounts with a pending interest to or from `account_id` (excluded from discovery)."""
    rows = (
        Interest.objects.filter(status="pending")
        .filter(Q(sender_id=account_id) | Q(recipient_id=account_id))
        .values_list("sender_id", "recipient_id")
    )
    return {b if a == account_id else a for a, b in rows}

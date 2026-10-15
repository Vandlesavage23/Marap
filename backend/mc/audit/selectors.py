import uuid

from django.db.models import QuerySet

from .models import AuditEvent


def search(
    *, target_id: uuid.UUID | None = None, action: str | None = None
) -> QuerySet[AuditEvent]:
    """Admin-only search (callers must enforce role policy)."""
    qs = AuditEvent.objects.all()
    if target_id:
        qs = qs.filter(target_id=target_id)
    if action:
        qs = qs.filter(action=action)
    return qs.order_by("-id")

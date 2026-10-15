import uuid
from datetime import datetime

from django.db import transaction

from mc.audit import services as audit
from mc.common.errors import ValidationFailed

from .models import StaffSession, SupportNote


def purge_dead_staff_sessions(*, before: datetime) -> int:
    """Delete portal sessions that expired or were revoked before `before` (retention)."""
    from django.db.models import Q

    n, _ = StaffSession.objects.filter(Q(expires_at__lt=before) | Q(revoked_at__lt=before)).delete()
    return n


def add_note(*, account_id: uuid.UUID, staff_id: uuid.UUID, role: str, body: str) -> SupportNote:
    body = body.strip()
    if not 3 <= len(body) <= 1000:
        raise ValidationFailed("Notes are 3-1,000 characters.")
    with transaction.atomic():
        note = SupportNote.objects.create(account_id=account_id, staff_id=staff_id, body=body)
        audit.record(
            actor_type="staff", actor_id=staff_id, role=role, action="support.note_added",
            target_type="account", target_id=account_id, reason="support note",
        )  # fmt: skip
    return note


def notes_for(account_id: uuid.UUID) -> list[SupportNote]:
    return list(
        SupportNote.objects.filter(account_id=account_id)
        .select_related("staff")
        .order_by("-id")[:50]
    )


def purge_notes_for(account_id: uuid.UUID) -> int:
    n, _ = SupportNote.objects.filter(account_id=account_id).delete()
    return n

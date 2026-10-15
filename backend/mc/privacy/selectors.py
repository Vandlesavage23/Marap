from django.db.models import QuerySet

from .models import PrivacyRequest


def open_deletion_requests() -> QuerySet[PrivacyRequest]:
    """Deletion requests still inside the grace period or on hold (admin: privacy queue)."""
    return PrivacyRequest.objects.filter(kind="delete", status__in=["pending", "held"]).order_by(
        "due_at"
    )

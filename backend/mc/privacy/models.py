from django.db import models

from mc.common.models import BaseModel


class PrivacyRequest(BaseModel):
    """Export / deletion request (Bible §7.10). Survives the account (account → NULL, `account_ref` keeps the id
    so the request can still be shown to the regulator)."""

    class Kind(models.TextChoices):
        EXPORT = "export"
        DELETE = "delete"

    class Status(models.TextChoices):
        PENDING = "pending"
        HELD = "held"  # legal/safety hold: hard deletion postponed
        COMPLETED = "completed"
        CANCELLED = "cancelled"
        FAILED = "failed"

    account = models.ForeignKey(
        "accounts.Account", null=True, on_delete=models.SET_NULL, related_name="privacy_requests"
    )
    account_ref = models.UUIDField()
    kind = models.CharField(max_length=8, choices=Kind.choices)
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.PENDING)
    requested_at = models.DateTimeField()
    due_at = models.DateTimeField(null=True, blank=True)  # deletion: end of grace; export: 72 h SLA
    completed_at = models.DateTimeField(null=True, blank=True)
    file_key = models.CharField(max_length=200, blank=True, default="")
    expires_at = models.DateTimeField(null=True, blank=True)  # export link expiry
    hold_reason = models.CharField(max_length=100, blank=True, default="")

    class Meta:
        indexes = [
            models.Index(fields=["kind", "status", "due_at"]),
            models.Index(fields=["account_ref"]),
        ]
        constraints = [
            models.UniqueConstraint(
                fields=["account_ref", "kind"],
                condition=models.Q(status__in=["pending", "held"]),
                name="uniq_open_privacy_request",
            )
        ]

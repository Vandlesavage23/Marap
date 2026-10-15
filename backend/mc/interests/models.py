from django.db import models

from mc.common.models import BaseModel


class InterestSnapshot(BaseModel):
    """The sender's description + display name as they were when the interest was sent (Bible §7.6).
    Deleted with the interest on block / account deletion."""

    description = models.ForeignKey(
        "profiles.Description", null=True, on_delete=models.SET_NULL, related_name="+"
    )
    text = models.TextField()
    display_name = models.CharField(max_length=30)


class Interest(BaseModel):
    class Status(models.TextChoices):
        PENDING = "pending"
        ACCEPTED = "accepted"
        PASSED = "passed"
        EXPIRED = "expired"
        CANCELLED = "cancelled"

    sender = models.ForeignKey(
        "accounts.Account", on_delete=models.CASCADE, related_name="interests_sent"
    )
    recipient = models.ForeignKey(
        "accounts.Account", on_delete=models.CASCADE, related_name="interests_received"
    )
    snapshot = models.OneToOneField(
        InterestSnapshot, null=True, on_delete=models.SET_NULL, related_name="interest"
    )
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.PENDING)
    idempotency_key = models.CharField(max_length=64)
    expires_at = models.DateTimeField()
    responded_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["sender", "idempotency_key"], name="uniq_interest_idem"
            ),
            models.UniqueConstraint(
                fields=["sender", "recipient"],
                condition=models.Q(status="pending"),
                name="uniq_pending_interest",
            ),
            models.CheckConstraint(
                condition=~models.Q(sender=models.F("recipient")), name="interest_not_self"
            ),
        ]
        indexes = [
            models.Index(fields=["recipient", "status", "-created_at"]),
            models.Index(fields=["sender", "-created_at"]),
        ]

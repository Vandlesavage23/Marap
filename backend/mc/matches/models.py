from django.db import models

from mc.common.models import BaseModel


class Match(BaseModel):
    """Mutual interest (Bible §7.7). `user_a < user_b` by UUID so a pair has one canonical row shape."""

    class Status(models.TextChoices):
        ACTIVE = "active"
        UNMATCHED = "unmatched"
        BLOCKED = "blocked"
        CLOSED_DELETED = "closed_deleted"

    user_a = models.ForeignKey("accounts.Account", on_delete=models.CASCADE, related_name="+")
    user_b = models.ForeignKey("accounts.Account", on_delete=models.CASCADE, related_name="+")
    status = models.CharField(max_length=16, choices=Status.choices, default=Status.ACTIVE)
    ended_at = models.DateTimeField(null=True, blank=True)
    ended_by = models.ForeignKey(
        "accounts.Account", null=True, blank=True, on_delete=models.SET_NULL, related_name="+"
    )
    # Set once both participants have sent a message (Phase 5 disclosure clock). Never reset.
    first_two_way_message_at = models.DateTimeField(null=True, blank=True)
    user_a_first_message_at = models.DateTimeField(null=True, blank=True)
    user_b_first_message_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["user_a", "user_b"],
                condition=models.Q(status="active"),
                name="uniq_active_match",
            ),
            models.CheckConstraint(
                condition=models.Q(user_a__lt=models.F("user_b")), name="match_ordered_pair"
            ),
        ]
        indexes = [
            models.Index(fields=["user_a", "status"]),
            models.Index(fields=["user_b", "status"]),
        ]

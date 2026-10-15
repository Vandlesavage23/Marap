from django.db import models

from mc.common.models import BaseModel


class AuditEvent(BaseModel):
    """Append-only audit trail (Bible §7.10). A DB trigger forbids UPDATE and DELETE.

    `metadata` must never contain PII (phones, emails, message text, descriptions, answers).
    """

    class ActorType(models.TextChoices):
        STAFF = "staff"
        SYSTEM = "system"
        MEMBER = "member"

    actor_type = models.CharField(max_length=10, choices=ActorType.choices)
    actor_id = models.UUIDField(null=True, blank=True)
    role = models.CharField(max_length=40, blank=True, default="")
    action = models.CharField(max_length=80, db_index=True)
    target_type = models.CharField(max_length=40, blank=True, default="")
    target_id = models.UUIDField(null=True, blank=True)
    reason = models.CharField(max_length=500, blank=True, default="")
    metadata = models.JSONField(default=dict, blank=True)
    ip_hmac = models.BinaryField(null=True, blank=True)

    class Meta:
        indexes = [
            models.Index(fields=["target_type", "target_id", "-created_at"]),
            models.Index(fields=["actor_id", "-created_at"]),
        ]

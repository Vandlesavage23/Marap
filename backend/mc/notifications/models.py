from django.db import models

from mc.common.models import BaseModel


class Notification(BaseModel):
    """In-app inbox entry (Bible §7.10). `payload` holds ids only — never names, text or other PII."""

    account = models.ForeignKey(
        "accounts.Account", on_delete=models.CASCADE, related_name="notifications"
    )
    type = models.CharField(max_length=30)
    payload = models.JSONField(default=dict)
    # The other member this entry is about (if any): lets a block purge it (Bible §10.8).
    counterpart = models.ForeignKey(
        "accounts.Account", null=True, blank=True, on_delete=models.CASCADE, related_name="+"
    )
    read_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        indexes = [
            models.Index(fields=["account", "-id"]),
            models.Index(fields=["account", "counterpart"]),
        ]

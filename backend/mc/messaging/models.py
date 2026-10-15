from django.db import models

from mc.common.models import BaseModel


class Message(BaseModel):
    """A chat message (Bible §7.7). `created_at` is the server clock; ordering is by UUIDv7 id."""

    class Kind(models.TextChoices):
        TEXT = "text"
        IMAGE = "image"
        VOICE = "voice"
        SYSTEM = "system"

    class Flag(models.TextChoices):
        FINANCIAL_REQUEST = "financial_request"

    match = models.ForeignKey("matches.Match", on_delete=models.CASCADE, related_name="messages")
    sender = models.ForeignKey(
        "accounts.Account", null=True, on_delete=models.SET_NULL, related_name="+"
    )
    client_msg_id = models.UUIDField(null=True, blank=True)
    kind = models.CharField(max_length=8, choices=Kind.choices)
    body = models.TextField(null=True, blank=True)  # noqa: DJ001 - NULL = no body (media/system)
    media = models.ForeignKey(
        "media.MediaObject", null=True, blank=True, on_delete=models.SET_NULL, related_name="+"
    )
    delivered_at = models.DateTimeField(null=True, blank=True)
    read_at = models.DateTimeField(null=True, blank=True)
    moderation_flag = models.CharField(max_length=20, choices=Flag.choices, null=True, blank=True)  # noqa: DJ001
    deleted_placeholder = models.BooleanField(
        default=False
    )  # sender deleted their account: "message deleted"

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["sender", "client_msg_id"],
                condition=models.Q(client_msg_id__isnull=False),
                name="uniq_message_client_id",
            ),
            models.CheckConstraint(
                condition=models.Q(kind="system")
                | models.Q(sender__isnull=False)
                | models.Q(deleted_placeholder=True),
                name="message_sender_required",
            ),
        ]
        indexes = [models.Index(fields=["match", "-id"])]

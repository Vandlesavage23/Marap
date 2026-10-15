from django.db import models

from mc.common.models import BaseModel


class MediaObject(BaseModel):
    """An uploaded file moving through the pipeline (Bible §7.8, §9.3). `storage_key` is the processed
    object (set when `ready`); the raw upload lives under `upload_key` and is deleted after processing."""

    class Purpose(models.TextChoices):
        PROFILE_PHOTO = "profile_photo"
        CHAT_IMAGE = "chat_image"
        VOICE_NOTE = "voice_note"

    class Status(models.TextChoices):
        AWAITING_UPLOAD = "awaiting_upload"
        SCANNING = "scanning"
        READY = "ready"
        REJECTED = "rejected"

    class Moderation(models.TextChoices):
        NOT_REQUIRED = "not_required"
        APPROVED = "approved"
        REVIEW = "review"
        REJECTED = "rejected"

    owner = models.ForeignKey("accounts.Account", on_delete=models.CASCADE, related_name="media")
    purpose = models.CharField(max_length=14, choices=Purpose.choices)
    declared_mime = models.CharField(max_length=40)
    declared_bytes = models.PositiveIntegerField()
    declared_sha256 = models.CharField(max_length=64, blank=True, default="")
    upload_key = models.CharField(max_length=200)
    storage_key = models.CharField(max_length=200, blank=True, default="")
    mime = models.CharField(max_length=40, blank=True, default="")
    bytes = models.PositiveIntegerField(null=True, blank=True)
    width = models.PositiveIntegerField(null=True, blank=True)
    height = models.PositiveIntegerField(null=True, blank=True)
    duration_ms = models.PositiveIntegerField(null=True, blank=True)
    sha256 = models.CharField(max_length=64, blank=True, default="")
    status = models.CharField(max_length=16, choices=Status.choices, default=Status.AWAITING_UPLOAD)
    reject_reason = models.CharField(max_length=40, blank=True, default="")
    moderation = models.CharField(
        max_length=14, choices=Moderation.choices, default=Moderation.NOT_REQUIRED
    )
    moderation_labels = models.JSONField(
        default=list, blank=True
    )  # label names only, no scores/PII
    face_count = models.PositiveSmallIntegerField(null=True, blank=True)
    processed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        indexes = [
            models.Index(fields=["owner", "-created_at"]),
            models.Index(fields=["status", "created_at"]),
        ]

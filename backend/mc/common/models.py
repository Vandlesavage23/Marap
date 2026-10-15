from django.db import models

from .ids import uuid7


class BaseModel(models.Model):
    """UUIDv7 primary key + created/updated timestamps (Bible §4.4, §7)."""

    id = models.UUIDField(primary_key=True, default=uuid7, editable=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True

from django.db import models

from mc.common.models import BaseModel


class FeatureFlag(BaseModel):
    """Runtime override of a feature flag (Bible §17). A missing row means "use the settings default"
    (`settings.FEATURE_FLAGS_DEFAULT`). Changes go through `services.set_flag` (audited)."""

    key = models.CharField(max_length=64, unique=True)
    enabled = models.BooleanField()
    description = models.CharField(max_length=200, blank=True, default="")
    updated_by = models.UUIDField(null=True, blank=True)  # staff id of the last change

    def __str__(self) -> str:
        return f"{self.key}={'on' if self.enabled else 'off'}"

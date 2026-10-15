from django.db import models

from mc.common.models import BaseModel


class ModelVersion(BaseModel):
    """A ranking model definition (Bible §7.5). v1 is the hand-weighted scorer."""

    name = models.CharField(max_length=40, unique=True)
    weights = models.JSONField(default=dict)
    created_by = models.UUIDField(null=True, blank=True)
    active = models.BooleanField(default=False)
    holdout_pct = models.PositiveSmallIntegerField(default=0)


class Impression(BaseModel):
    """A candidate shown to a viewer. Used for exposure caps, repeat-hiding and ranking evaluation.
    Retention 180 days (A). The numeric score is stored for evaluation but is never returned to clients."""

    class Action(models.TextChoices):
        INTEREST = "interest"
        PASS = "pass"  # noqa: S105
        NOT_RELEVANT = "not_relevant"

    viewer = models.ForeignKey("accounts.Account", on_delete=models.CASCADE, related_name="+")
    candidate = models.ForeignKey("accounts.Account", on_delete=models.CASCADE, related_name="+")
    score = models.DecimalField(max_digits=5, decimal_places=4)
    model_version = models.CharField(max_length=40)
    position = models.PositiveSmallIntegerField()
    shown_at = models.DateTimeField()
    action = models.CharField(max_length=14, choices=Action.choices, null=True, blank=True)  # noqa: DJ001

    class Meta:
        indexes = [
            models.Index(fields=["viewer", "candidate", "-shown_at"]),
            models.Index(fields=["candidate", "shown_at"]),
        ]

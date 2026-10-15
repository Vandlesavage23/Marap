from django.db import models

from mc.common.crypto import EncryptedTextField
from mc.common.models import BaseModel


class InviteCode(BaseModel):
    """Closed-beta invite (MC-127). Plain code (not a secret credential: it only gates sign-up)."""

    code = models.CharField(max_length=16, unique=True)
    max_uses = models.PositiveIntegerField(default=1)
    uses = models.PositiveIntegerField(default=0)
    expires_at = models.DateTimeField(null=True, blank=True)
    active = models.BooleanField(default=True)
    note = models.CharField(max_length=120, blank=True, default="")
    created_by = models.UUIDField(null=True, blank=True)  # StaffUser id

    class Meta:
        constraints = [
            models.CheckConstraint(
                condition=models.Q(uses__lte=models.F("max_uses")), name="invite_uses_within_max"
            )
        ]


class InviteRedemption(BaseModel):
    invite = models.ForeignKey(InviteCode, on_delete=models.CASCADE, related_name="redemptions")
    account_id = models.UUIDField(unique=True)  # one invite per account; erased with the account


class BetaFeedback(BaseModel):
    account_id = models.UUIDField(db_index=True)  # erased with the account
    screen = models.CharField(max_length=40, blank=True, default="")
    rating = models.PositiveSmallIntegerField(null=True, blank=True)
    message = EncryptedTextField()
    app_version = models.CharField(max_length=32, blank=True, default="")


class DistrictCap(BaseModel):
    """Throttle how many profiles may go live per district per day (Kampala date). No row = unlimited."""

    district = models.CharField(max_length=60, unique=True)
    daily_cap = models.PositiveIntegerField(null=True, blank=True)
    paused = models.BooleanField(default=False)
    count_date = models.DateField(null=True, blank=True)
    count = models.PositiveIntegerField(default=0)

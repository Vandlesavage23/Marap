from django.db import models

from mc.common.models import BaseModel


class Trial(BaseModel):
    """One free 24 h trial per human (identity_hmac). The row outlives the account (account → NULL on
    hard delete) so deleting and re-registering cannot buy a second trial (Bible §10.7, §10.9)."""

    account = models.OneToOneField(
        "accounts.Account", null=True, on_delete=models.SET_NULL, related_name="trial"
    )
    identity_hmac = models.BinaryField(unique=True)
    started_at = models.DateTimeField()
    ends_at = models.DateTimeField()


class Entitlement(BaseModel):
    """Membership window. Member = a row with starts_at ≤ now < ends_at and revoked_at null."""

    class Source(models.TextChoices):
        TRIAL = "trial"
        PURCHASE = "purchase"
        GRANT = "grant"

    account = models.ForeignKey(
        "accounts.Account", on_delete=models.CASCADE, related_name="entitlements"
    )
    source = models.CharField(max_length=10, choices=Source.choices)
    purchase_id = models.UUIDField(
        null=True, blank=True
    )  # billing.Purchase (FK once billing lands)
    starts_at = models.DateTimeField()
    ends_at = models.DateTimeField()
    revoked_at = models.DateTimeField(null=True, blank=True)
    reason = models.CharField(max_length=200, blank=True, default="")

    class Meta:
        indexes = [models.Index(fields=["account", "ends_at"])]
        constraints = [
            models.CheckConstraint(
                condition=models.Q(ends_at__gt=models.F("starts_at")), name="ent_window_valid"
            )
        ]

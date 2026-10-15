from django.db import models

from mc.common.crypto import EncryptedTextField
from mc.common.models import BaseModel


class Product(BaseModel):
    """A membership period for sale (Bible §7.9). Prices are integer minor units; UGX has no minor unit."""

    code = models.CharField(max_length=30, unique=True)
    duration_days = models.PositiveSmallIntegerField()
    price_minor = models.PositiveIntegerField()
    currency = models.CharField(max_length=3, default="UGX")
    apple_product_id = models.CharField(max_length=100, blank=True, default="")
    google_product_id = models.CharField(max_length=100, blank=True, default="")
    web_enabled = models.BooleanField(default=False)
    active = models.BooleanField(default=True)


class PaymentEvent(BaseModel):
    """Append-only ledger of everything a payment provider (or client) told us (CLAUDE.md rule 7).

    Unique per `(provider, provider_event_id)`. The provider facts (`raw`, `normalized`, signature result,
    timestamps) are immutable — a DB trigger rejects changing them or deleting rows. Only the processing
    bookkeeping (`process_status`, `processed_at`, `error`, `account`) may change.
    """

    class Provider(models.TextChoices):
        APPLE = "apple"
        GOOGLE = "google"
        FLUTTERWAVE = "flutterwave"

    class Status(models.TextChoices):
        PENDING = "pending"
        PROCESSED = "processed"
        IGNORED = "ignored"
        FAILED = "failed"

    provider = models.CharField(max_length=12, choices=Provider.choices)
    provider_event_id = models.CharField(max_length=200)
    event_type = models.CharField(max_length=60)
    account = models.ForeignKey(
        "accounts.Account", null=True, on_delete=models.SET_NULL, related_name="+"
    )
    raw = models.JSONField(default=dict)  # secrets stripped before storing
    normalized = models.JSONField(
        default=dict
    )  # provider-agnostic facts (see `events.NormalizedEvent`)
    signature_valid = models.BooleanField()
    received_at = models.DateTimeField()
    processed_at = models.DateTimeField(null=True, blank=True)
    process_status = models.CharField(max_length=10, choices=Status.choices, default=Status.PENDING)
    error = models.CharField(max_length=300, blank=True, default="")

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["provider", "provider_event_id"], name="uniq_payment_event"
            )
        ]
        indexes = [models.Index(fields=["process_status", "received_at"])]


class Purchase(BaseModel):
    """One subscription / prepaid period purchase. State is *derived* from its PaymentEvents (never edited
    by hand) so replaying or reordering events can't change the outcome."""

    class Status(models.TextChoices):
        PENDING = "pending"
        ACTIVE = "active"
        EXPIRED = "expired"
        REFUNDED = "refunded"
        REVOKED = "revoked"

    # Purchases are retained for tax law after account deletion, hence SET_NULL.
    account = models.ForeignKey(
        "accounts.Account", null=True, on_delete=models.SET_NULL, related_name="purchases"
    )
    provider = models.CharField(max_length=12, choices=PaymentEvent.Provider.choices)
    product = models.ForeignKey(Product, on_delete=models.PROTECT, related_name="purchases")
    # Apple/Google: the store's original transaction / purchase token id. Flutterwave: our tx_ref (= purchase id).
    original_transaction_id = models.CharField(max_length=200)
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.PENDING)
    period_start = models.DateTimeField(null=True, blank=True)
    period_end = models.DateTimeField(null=True, blank=True)
    auto_renew = models.BooleanField(default=False)
    amount_minor = models.PositiveIntegerField(
        default=0
    )  # what we expect to be paid (web) / last charge (store)
    currency = models.CharField(max_length=3, default="UGX")
    last_event = models.ForeignKey(
        PaymentEvent, null=True, on_delete=models.SET_NULL, related_name="+"
    )
    # Google Play purchase token (needed to re-query Google in reconciliation). Field-encrypted; never logged.
    provider_token = EncryptedTextField(null=True, blank=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["provider", "original_transaction_id"], name="uniq_purchase_txn"
            )
        ]
        indexes = [
            models.Index(fields=["account", "-created_at"]),
            models.Index(fields=["status", "period_end"]),
        ]

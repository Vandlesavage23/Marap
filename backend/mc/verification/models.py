from django.db import models

from mc.common.crypto import EncryptedTextField
from mc.common.models import BaseModel


class VerificationAttempt(BaseModel):
    """One identity-verification attempt (Bible §7.2). We never store the ID number or any images:
    only an HMAC of the normalised number, the date of birth and a minimal (encrypted) vendor result."""

    class Status(models.TextChoices):
        CREATED = "created"
        SUBMITTED = "submitted"
        PASSED = "passed"
        FAILED = "failed"
        NEEDS_REVIEW = "needs_review"
        ERROR = "error"
        EXPIRED = "expired"

    class Vendor(models.TextChoices):
        SMILE_ID = "smile_id"

    # Retained after account deletion for fraud prevention (decision only), hence SET_NULL.
    account = models.ForeignKey(
        "accounts.Account",
        null=True,
        on_delete=models.SET_NULL,
        related_name="verification_attempts",
    )
    vendor = models.CharField(max_length=20, choices=Vendor.choices, default=Vendor.SMILE_ID)
    vendor_job_id = models.CharField(max_length=64, unique=True)
    status = models.CharField(max_length=14, choices=Status.choices, default=Status.CREATED)
    reason_code = models.CharField(max_length=40, blank=True, default="")
    id_type = models.CharField(max_length=30, blank=True, default="")
    issuing_country = models.CharField(max_length=2, blank=True, default="")
    date_of_birth = models.DateField(null=True, blank=True)
    id_number_hmac = models.BinaryField(null=True, blank=True)
    vendor_result = EncryptedTextField(null=True, blank=True)  # JSON text, encrypted at rest
    submitted_at = models.DateTimeField(null=True, blank=True)
    decided_at = models.DateTimeField(null=True, blank=True)
    reviewed_by = models.UUIDField(
        null=True, blank=True
    )  # StaffUser id (FK once adminportal lands)
    safety_flag = models.CharField(max_length=30, blank=True, default="")

    class Meta:
        constraints = [
            # one verified identity → one account
            models.UniqueConstraint(
                fields=["id_number_hmac"],
                condition=models.Q(
                    status="passed", account__isnull=False
                ),  # a deleted account frees its identity
                name="uniq_passed_identity",
            ),
        ]
        indexes = [models.Index(fields=["account", "-created_at"])]


class VerificationAppeal(BaseModel):
    """A member's appeal of a final verification failure (Bible §7.2). One open appeal per attempt."""

    class Status(models.TextChoices):
        OPEN = "open"
        UPHELD = "upheld"  # the appeal succeeded: the attempt is re-decided as passed
        REJECTED = "rejected"

    attempt = models.ForeignKey(
        VerificationAttempt, on_delete=models.CASCADE, related_name="appeals"
    )
    account = models.ForeignKey(
        "accounts.Account", null=True, on_delete=models.SET_NULL, related_name="+"
    )
    message = EncryptedTextField()
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.OPEN)
    decided_by = models.UUIDField(null=True, blank=True)
    decided_at = models.DateTimeField(null=True, blank=True)
    decision_reason = models.CharField(max_length=500, blank=True, default="")

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["attempt"],
                condition=models.Q(status="open"),
                name="uniq_open_verification_appeal",
            )
        ]

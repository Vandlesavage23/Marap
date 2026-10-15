from django.db import models
from django.db.models.functions import Lower

from mc.common.models import BaseModel

from . import constants


class Account(BaseModel):
    """A member account (Bible §7.1). Staff are separate (`StaffUser`). `str()` never exposes the phone."""

    class Status(models.TextChoices):
        PENDING_VERIFICATION = constants.PENDING_VERIFICATION
        ACTIVE = constants.ACTIVE
        SUSPENDED = constants.SUSPENDED
        DEACTIVATED = constants.DEACTIVATED
        DELETED = constants.DELETED

    class Role(models.TextChoices):
        MEMBER = "member"

    phone_e164 = models.CharField(max_length=16, unique=True)
    # Case-insensitive uniqueness via the Lower(email) constraint (CITextField was removed in Django 5.2).
    email = models.EmailField(null=True, blank=True)  # noqa: DJ001 - nullable+unique
    email_verified_at = models.DateTimeField(null=True, blank=True)
    status = models.CharField(
        max_length=24, choices=Status.choices, default=Status.PENDING_VERIFICATION
    )
    role = models.CharField(max_length=10, choices=Role.choices, default=Role.MEMBER)
    last_seen_at = models.DateTimeField(null=True, blank=True)
    locale = models.CharField(max_length=10, default="en")
    country_of_residence = models.CharField(max_length=2, blank=True, default="")

    class Meta:
        constraints = [models.UniqueConstraint(Lower("email"), name="uniq_account_email_ci")]

    is_anonymous = False
    is_authenticated = True

    def __str__(self) -> str:
        return f"Account({self.id})"


class Device(BaseModel):
    class Platform(models.TextChoices):
        ANDROID = "android"
        IOS = "ios"

    account = models.ForeignKey(Account, on_delete=models.CASCADE, related_name="devices")
    # Client-generated per-install id (addition to §7.1: needed to recognise a returning device).
    install_id = models.UUIDField()
    platform = models.CharField(max_length=10, choices=Platform.choices)
    push_token = models.CharField(max_length=512, null=True, blank=True)  # noqa: DJ001
    app_version = models.CharField(max_length=32, blank=True, default="")
    os_version = models.CharField(max_length=32, blank=True, default="")
    first_seen_at = models.DateTimeField(auto_now_add=True)
    last_seen_at = models.DateTimeField(auto_now=True)
    trusted = models.BooleanField(default=False)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["account", "install_id"], name="uniq_device_install"),
            models.UniqueConstraint(
                fields=["platform", "push_token"],
                condition=models.Q(push_token__isnull=False),
                name="uniq_push_token_per_platform",
            ),
        ]


class Session(BaseModel):
    """Refresh-token session. Rotation links `rotated_from`; every row of one login shares `chain_id`
    so reuse of a rotated token can revoke the whole chain."""

    class RevokeReason(models.TextChoices):
        ROTATED = "rotated"
        LOGOUT = "logout"
        USER = "user"
        REUSE_DETECTED = "reuse_detected"
        ENFORCEMENT = "enforcement"
        ACCOUNT = "account"

    account = models.ForeignKey(Account, on_delete=models.CASCADE, related_name="sessions")
    device = models.ForeignKey(
        Device, null=True, on_delete=models.SET_NULL, related_name="sessions"
    )
    chain_id = models.UUIDField(db_index=True)
    refresh_token_hash = models.CharField(max_length=64, unique=True)
    issued_at = models.DateTimeField()
    expires_at = models.DateTimeField()
    rotated_from = models.ForeignKey("self", null=True, on_delete=models.SET_NULL, related_name="+")
    revoked_at = models.DateTimeField(null=True, blank=True)
    revoke_reason = models.CharField(max_length=20, choices=RevokeReason.choices, blank=True)

    class Meta:
        indexes = [models.Index(fields=["account", "revoked_at", "-expires_at"])]


class ConsentRecord(BaseModel):
    """Append-only (DB trigger). Current consent = latest row per kind."""

    class Kind(models.TextChoices):
        TERMS = "terms"
        PRIVACY = "privacy"
        DATA_TRANSFER = "data_transfer"
        SPECIAL_RELIGION = "special_religion"
        SPECIAL_FINANCE = "special_finance"
        MARRIED_VISIBILITY = "married_visibility"
        MARKETING = "marketing"

    class Source(models.TextChoices):
        APP = "app"
        WEB = "web"

    account = models.ForeignKey(Account, on_delete=models.CASCADE, related_name="consents")
    kind = models.CharField(max_length=24, choices=Kind.choices)
    version = models.CharField(max_length=20)
    granted = models.BooleanField()
    source = models.CharField(max_length=4, choices=Source.choices)
    ip_hmac = models.BinaryField(null=True, blank=True)

    class Meta:
        indexes = [models.Index(fields=["account", "kind", "-id"])]


class RecoverySession(BaseModel):
    """Lost-phone recovery (Bible §10.1 step 4): email OTP → biometric re-check → verify the NEW phone → swap.
    Rows are the audit trail of who recovered what and when."""

    class State(models.TextChoices):
        EMAIL_SENT = "email_sent"
        EMAIL_VERIFIED = "email_verified"
        BIOMETRIC_PENDING = "biometric_pending"
        BIOMETRIC_PASSED = "biometric_passed"
        COMPLETED = "completed"
        FAILED = "failed"

    account = models.ForeignKey(Account, on_delete=models.CASCADE, related_name="recoveries")
    state = models.CharField(max_length=20, choices=State.choices, default=State.EMAIL_SENT)
    biometric_job_id = models.CharField(max_length=64, blank=True, default="")
    expires_at = models.DateTimeField()
    completed_at = models.DateTimeField(null=True, blank=True)
    ip_hmac = models.BinaryField(null=True, blank=True)

    class Meta:
        indexes = [
            models.Index(fields=["account", "-created_at"]),
            models.Index(fields=["biometric_job_id"]),
        ]

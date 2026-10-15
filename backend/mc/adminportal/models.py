from django.contrib.postgres.fields import ArrayField
from django.db import models

from mc.common.crypto import EncryptedTextField
from mc.common.models import BaseModel


class StaffUser(BaseModel):
    """A staff member (Bible §6.3). Separate from member accounts; invite-only (created by a superadmin via
    `manage.py create_staff`), signs in with SSO and MUST use TOTP MFA."""

    email = models.EmailField(unique=True)
    name = models.CharField(max_length=120)
    roles = ArrayField(models.CharField(max_length=30), default=list)
    active = models.BooleanField(default=True)
    sso_subject = models.CharField(max_length=255, null=True, blank=True, unique=True)
    totp_secret = EncryptedTextField(null=True, blank=True)
    totp_enrolled_at = models.DateTimeField(null=True, blank=True)
    totp_last_step = models.BigIntegerField(default=0)  # replay protection: a code is usable once
    last_login_at = models.DateTimeField(null=True, blank=True)


class StaffSession(BaseModel):
    """Server-side portal session: 8 h, separate cookie. `mfa_verified_at` gates everything; `reauth_at` gates
    sensitive actions (step-up)."""

    staff = models.ForeignKey(StaffUser, on_delete=models.CASCADE, related_name="sessions")
    token_hash = models.CharField(max_length=64, unique=True)
    expires_at = models.DateTimeField()
    mfa_verified_at = models.DateTimeField(null=True, blank=True)
    reauth_at = models.DateTimeField(null=True, blank=True)
    ip_hmac = models.BinaryField(null=True, blank=True)
    revoked_at = models.DateTimeField(null=True, blank=True)
    sso_state = models.CharField(max_length=64, blank=True, default="")


class SupportNote(BaseModel):
    """Free-text note a support agent leaves on a member's case. Append-only (no edit UI), field-encrypted, erased
    with the account. Notes must never contain chat content or special data — the form says so."""

    account_id = models.UUIDField(db_index=True)  # not an FK: this module never joins accounts
    staff = models.ForeignKey(StaffUser, on_delete=models.PROTECT, related_name="notes")
    body = EncryptedTextField()

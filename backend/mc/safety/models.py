from django.db import models

from mc.common.crypto import EncryptedTextField
from mc.common.models import BaseModel


class Block(BaseModel):
    """`blocker` has blocked `blocked` (Bible §7.10). Blocks are absolute and two-way in effect."""

    blocker = models.ForeignKey(
        "accounts.Account", on_delete=models.CASCADE, related_name="blocks_made"
    )
    blocked = models.ForeignKey(
        "accounts.Account", on_delete=models.CASCADE, related_name="blocks_received"
    )

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["blocker", "blocked"], name="uniq_block"),
            models.CheckConstraint(
                condition=~models.Q(blocker=models.F("blocked")), name="block_not_self"
            ),
        ]
        indexes = [models.Index(fields=["blocked"])]


class Report(BaseModel):
    """A member's report about another member (Bible §7.10). Evidence is copied at report time so moderators
    never browse chats. Free text and evidence are field-encrypted."""

    class Category(models.TextChoices):
        SCAM = "scam"
        FINANCIAL_REQUEST = "financial_request"
        HARASSMENT = "harassment"
        SEXUAL_CONTENT = "sexual_content"
        THREAT = "threat"
        UNDERAGE = "underage"
        IMPERSONATION = "impersonation"
        MARRIED_CONCEALED = "married_concealed"
        FAKE_PROFILE = "fake_profile"
        SPAM = "spam"
        OTHER = "other"

    class ContextType(models.TextChoices):
        PROFILE = "profile"
        INTEREST = "interest"
        MESSAGE = "message"

    class Status(models.TextChoices):
        OPEN = "open"
        ACTIONED = "actioned"
        DISMISSED = "dismissed"

    reporter = models.ForeignKey(
        "accounts.Account", on_delete=models.CASCADE, related_name="reports_made"
    )
    subject = models.ForeignKey(
        "accounts.Account", on_delete=models.CASCADE, related_name="reports_about"
    )
    category = models.CharField(max_length=20, choices=Category.choices)
    context_type = models.CharField(max_length=10, choices=ContextType.choices)
    context_id = models.UUIDField(null=True, blank=True)
    text = EncryptedTextField(null=True, blank=True)
    severity = models.CharField(max_length=2)  # s1..s4, computed from category
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.OPEN)
    case = models.ForeignKey("Case", null=True, on_delete=models.SET_NULL, related_name="reports")
    idempotency_key = models.CharField(max_length=64)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["reporter", "idempotency_key"], name="uniq_report_idem")
        ]
        indexes = [
            models.Index(fields=["subject", "-id"]),
            models.Index(fields=["status", "severity"]),
        ]


class ReportEvidence(BaseModel):
    report = models.ForeignKey(Report, on_delete=models.CASCADE, related_name="evidence")
    kind = models.CharField(max_length=20)  # message | interest_snapshot | profile_snapshot
    position = models.PositiveSmallIntegerField(default=0)
    content = EncryptedTextField()  # JSON


class Case(BaseModel):
    """Moderation unit of work: all open reports about one member."""

    class Status(models.TextChoices):
        OPEN = "open"
        CLOSED = "closed"

    subject = models.ForeignKey(
        "accounts.Account", on_delete=models.CASCADE, related_name="safety_cases"
    )
    severity = models.CharField(max_length=2)
    status = models.CharField(max_length=8, choices=Status.choices, default=Status.OPEN)
    assigned_to = models.UUIDField(null=True, blank=True)  # StaffUser id
    sla_due_at = models.DateTimeField()
    closed_at = models.DateTimeField(null=True, blank=True)
    resolution = models.CharField(max_length=20, blank=True, default="")

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["subject"],
                condition=models.Q(status="open"),
                name="uniq_open_case_per_subject",
            )
        ]
        indexes = [models.Index(fields=["status", "severity", "sla_due_at"])]


class Action(BaseModel):
    """An enforcement action (append-only record). Effects are applied by `take_action`."""

    class Kind(models.TextChoices):
        WARN = "warn"
        HIDE_CONTENT = "hide_content"
        SUSPEND_7D = "suspend_7d"
        BAN = "ban"
        REINSTATE = "reinstate"

    case = models.ForeignKey(Case, null=True, on_delete=models.SET_NULL, related_name="actions")
    subject = models.ForeignKey(
        "accounts.Account", on_delete=models.CASCADE, related_name="enforcement_actions"
    )
    kind = models.CharField(max_length=14, choices=Kind.choices)
    actor_id = models.UUIDField()  # StaffUser id
    reason = models.CharField(max_length=500)
    expires_at = models.DateTimeField(null=True, blank=True)
    lifted_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        indexes = [
            models.Index(fields=["subject", "-id"]),
            models.Index(fields=["kind", "expires_at"]),
        ]


class Ban(BaseModel):
    """A banned *person* (keyed hash of the verified ID number) so a new phone cannot start over."""

    identity_hmac = models.BinaryField(unique=True)
    account = models.ForeignKey(
        "accounts.Account", null=True, on_delete=models.SET_NULL, related_name="+"
    )
    reason = models.CharField(max_length=500)


class EnforcementAppeal(BaseModel):
    """A member's appeal of one enforcement action. One per action; decided by a different reviewer."""

    class Status(models.TextChoices):
        OPEN = "open"
        UPHELD = "upheld"  # the appeal succeeded: the action is overturned
        REJECTED = "rejected"

    action = models.OneToOneField(Action, on_delete=models.CASCADE, related_name="appeal")
    account = models.ForeignKey(
        "accounts.Account", on_delete=models.CASCADE, related_name="enforcement_appeals"
    )
    message = EncryptedTextField()
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.OPEN)
    decided_by = models.UUIDField(null=True, blank=True)
    decided_at = models.DateTimeField(null=True, blank=True)
    decision_reason = models.CharField(max_length=500, blank=True, default="")

from django.db import models

from mc.common.crypto import EncryptedTextField
from mc.common.models import BaseModel


class Question(BaseModel):
    """Seeded, versioned reference data (Bible §7.4). Content owned by the product team."""

    class Dimension(models.TextChoices):
        INTENT = "intent"
        CHILDREN = "children"
        FAITH = "faith"
        MARRIAGE_FORM = "marriage_form"
        FAMILY = "family"
        ROLES = "roles"
        COMMUNICATION = "communication"
        LIFESTYLE = "lifestyle"
        MONEY = "money"
        LOCATION = "location"

    class Type(models.TextChoices):
        SINGLE = "single"
        MULTI = "multi"
        SCALE = "scale"

    key = models.CharField(max_length=60, unique=True)
    version = models.PositiveSmallIntegerField(default=1)
    dimension = models.CharField(max_length=20, choices=Dimension.choices)
    type = models.CharField(max_length=8, choices=Type.choices)
    prompt = models.CharField(max_length=300)  # English copy; translations live in catalogs later
    options = models.JSONField(
        default=list
    )  # single/multi: [{value,label}]; scale: {min,max,min_label,max_label}
    is_core = models.BooleanField(default=True)
    is_special = models.BooleanField(default=False)
    consent_kind = models.CharField(max_length=24, blank=True, default="")  # required for special
    allow_dealbreaker = models.BooleanField(default=True)
    scoring_allowed = models.BooleanField(
        default=True
    )  # special data stays out of ranking unless true
    scoring = models.JSONField(default=dict)
    position = models.PositiveSmallIntegerField(default=0)
    active = models.BooleanField(default=True)

    class Meta:
        ordering = ["position", "key"]


class Answer(BaseModel):
    account = models.ForeignKey(
        "accounts.Account", on_delete=models.CASCADE, related_name="answers"
    )
    question = models.ForeignKey(Question, on_delete=models.CASCADE, related_name="answers")
    question_version = models.PositiveSmallIntegerField()
    value = models.JSONField(null=True, blank=True)  # NULL for special questions
    value_enc = EncryptedTextField(null=True, blank=True)  # JSON text, special questions only
    importance = models.PositiveSmallIntegerField(default=2)  # 1..3
    is_dealbreaker = models.BooleanField(default=False)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["account", "question"], name="uniq_answer_per_question"
            ),
            models.CheckConstraint(
                condition=models.Q(importance__gte=1, importance__lte=3),
                name="answer_importance_1_3",
            ),
            models.CheckConstraint(
                condition=models.Q(value__isnull=True) | models.Q(value_enc__isnull=True),
                name="answer_value_xor_enc",
            ),
        ]
        indexes = [models.Index(fields=["question", "account"])]

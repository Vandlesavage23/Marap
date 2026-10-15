from django.contrib.postgres.fields import ArrayField
from django.db import models

from mc.common.crypto import EncryptedTextField
from mc.common.models import BaseModel


class Profile(BaseModel):
    """1–1 with Account (Bible §7.3). Legal name / ID numbers are never stored here. Special personal
    data (religion*) is optional, consent-gated and encrypted; it is never used in ranking."""

    class Status(models.TextChoices):
        DRAFT = "draft"
        LIVE = "live"
        HIDDEN_BY_USER = "hidden_by_user"
        SUSPENDED = "suspended"

    class Gender(models.TextChoices):
        MALE = "male"
        FEMALE = "female"

    class Intention(models.TextChoices):
        MARRIAGE_SOON = "marriage_soon"
        MARRIAGE_OPEN_TIMELINE = "marriage_open_timeline"

    class Timeline(models.TextChoices):
        WITHIN_1Y = "within_1y"
        Y1_2 = "1_2y"
        Y2_4 = "2_4y"
        OPEN = "open"

    class MaritalStatus(models.TextChoices):
        NEVER_MARRIED = "never_married"
        DIVORCED = "divorced"
        WIDOWED = "widowed"
        MARRIED_CUSTOMARY = "married_customary"
        MARRIED_ISLAMIC = "married_islamic"

    class MarriageForm(models.TextChoices):
        MONOGAMOUS_ONLY = "monogamous_only"
        OPEN_TO_CUSTOMARY_OR_ISLAMIC = "open_to_customary_or_islamic"

    class HasChildren(models.TextChoices):
        NO = "no"
        YES_LIVING_WITH_ME = "yes_living_with_me"
        YES_NOT_LIVING_WITH_ME = "yes_not_living_with_me"

    class WantsChildren(models.TextChoices):
        YES = "yes"
        NO = "no"
        UNSURE = "unsure"

    class Education(models.TextChoices):
        PRIMARY = "primary"
        SECONDARY = "secondary"
        CERTIFICATE_DIPLOMA = "certificate_diploma"
        BACHELORS = "bachelors"
        POSTGRADUATE = "postgraduate"

    account = models.OneToOneField(
        "accounts.Account", on_delete=models.CASCADE, related_name="profile"
    )
    display_name = models.CharField(max_length=30, blank=True, default="")
    gender = models.CharField(max_length=6, choices=Gender.choices, blank=True, default="")
    birth_date = models.DateField()  # copied from passed verification; never editable
    district = models.CharField(max_length=40, blank=True, default="")
    # Coarse location (rounded to ~1 km). PostGIS geography(Point) is deferred — see ADR-0002.
    location_lat = models.DecimalField(max_digits=6, decimal_places=2, null=True, blank=True)
    location_lng = models.DecimalField(max_digits=7, decimal_places=2, null=True, blank=True)
    diaspora_country = models.CharField(max_length=2, blank=True, default="")
    intention = models.CharField(max_length=24, choices=Intention.choices, blank=True, default="")
    marriage_timeline = models.CharField(
        max_length=10, choices=Timeline.choices, blank=True, default=""
    )
    marital_status = models.CharField(
        max_length=20, choices=MaritalStatus.choices, blank=True, default=""
    )
    married_declaration_at = models.DateTimeField(null=True, blank=True)
    marriage_form_preference = models.CharField(
        max_length=30, choices=MarriageForm.choices, blank=True, default=""
    )
    show_married_profiles = models.BooleanField(default=False)  # PENDING OD-03: opt-in default
    has_children = models.CharField(
        max_length=24, choices=HasChildren.choices, blank=True, default=""
    )
    wants_children = models.CharField(
        max_length=8, choices=WantsChildren.choices, blank=True, default=""
    )
    languages = ArrayField(models.CharField(max_length=3), default=list, blank=True, size=8)
    religion = EncryptedTextField(null=True, blank=True)  # special data, consent `special_religion`
    religion_practice = EncryptedTextField(null=True, blank=True)
    occupation = models.CharField(max_length=60, blank=True, default="")
    education = models.CharField(max_length=24, choices=Education.choices, blank=True, default="")
    status = models.CharField(max_length=16, choices=Status.choices, default=Status.DRAFT)
    completeness = models.PositiveSmallIntegerField(default=0)

    class Meta:
        indexes = [
            models.Index(fields=["status", "gender", "birth_date"]),
            models.Index(fields=["status", "district"]),
        ]

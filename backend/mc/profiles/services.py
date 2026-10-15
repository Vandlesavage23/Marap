"""Profile writes (Bible §7.3, §10.3)."""

import uuid
from decimal import ROUND_HALF_UP, Decimal
from typing import TYPE_CHECKING, Any

from django.conf import settings
from django.db import IntegrityError, transaction
from django.utils import timezone

from mc.accounts import selectors as account_selectors
from mc.common.errors import Conflict, MarriedNotEligible, NotVerified, ValidationFailed
from mc.verification import selectors as verification_selectors

from . import selectors
from .districts import VALID_DISTRICTS
from .models import Profile
from .names import normalise_display_name

if TYPE_CHECKING:
    from mc.accounts.models import Account

SPECIAL_FIELDS = {"religion": "special_religion", "religion_practice": "special_religion"}
MARRIED = {Profile.MaritalStatus.MARRIED_CUSTOMARY, Profile.MaritalStatus.MARRIED_ISLAMIC}
IMMUTABLE_ONCE_SET = ("gender",)
ENUM_FIELDS = {
    "gender": Profile.Gender,
    "intention": Profile.Intention,
    "marriage_timeline": Profile.Timeline,
    "marital_status": Profile.MaritalStatus,
    "marriage_form_preference": Profile.MarriageForm,
    "has_children": Profile.HasChildren,
    "wants_children": Profile.WantsChildren,
    "education": Profile.Education,
}
EDITABLE = (
    "display_name", "gender", "district", "diaspora_country", "intention", "marriage_timeline",
    "marital_status", "marriage_form_preference", "show_married_profiles", "has_children",
    "wants_children", "languages", "religion", "religion_practice", "occupation", "education",
)  # fmt: skip


def get_or_create_profile(*, account: "Account") -> Profile:
    """Profiles exist only for verified adults; birth_date comes from the passed verification."""
    dob = verification_selectors.verified_date_of_birth(account)
    if dob is None:
        raise NotVerified("Verify your identity before building your profile.")
    profile, _ = Profile.objects.get_or_create(
        account=account,
        defaults={
            "birth_date": dob,
            "show_married_profiles": settings.MARRIED_VISIBILITY_DEFAULT,
        },
    )
    return profile


def _coarse(value: Any, places: str = "0.01") -> Decimal:
    return Decimal(str(value)).quantize(Decimal(places), rounding=ROUND_HALF_UP)


def update_profile(*, account: "Account", data: dict[str, Any]) -> Profile:
    """Apply a partial update, validating every rule in §7.3. All-or-nothing."""
    unknown = set(data) - set(EDITABLE) - {"married_declaration", "location"}
    if unknown:
        raise ValidationFailed(f"Unknown fields: {', '.join(sorted(unknown))}")
    get_or_create_profile(
        account=account
    )  # outside the update txn: a rejected PATCH keeps the draft
    with transaction.atomic():
        profile = Profile.objects.select_for_update().get(account=account)
        if profile.status == Profile.Status.SUSPENDED:
            raise Conflict("This profile is suspended.")

        for field, enum in ENUM_FIELDS.items():
            if field in data and data[field] not in (*enum.values, ""):
                raise ValidationFailed(f"Invalid value for {field}.")
        if "gender" in data and profile.gender and data["gender"] != profile.gender:
            raise Conflict("Gender can't be changed. Contact support if it was entered wrongly.")
        if "display_name" in data:
            data["display_name"] = normalise_display_name(data["display_name"])
        if "district" in data and data["district"] not in VALID_DISTRICTS:
            raise ValidationFailed("Choose a district from the list, or 'abroad'.")
        if "languages" in data:
            langs = [str(x).lower() for x in data["languages"]]
            if len(langs) > 8 or any(not (2 <= len(x) <= 3 and x.isalpha()) for x in langs):
                raise ValidationFailed("Languages must be ISO 639 codes (max 8).")
            data["languages"] = list(dict.fromkeys(langs))
        if "occupation" in data and len(data["occupation"]) > 60:
            raise ValidationFailed("Occupation is too long.")

        for field, kind in SPECIAL_FIELDS.items():
            if data.get(field) not in (None, "") and not account_selectors.has_consent(
                account, kind
            ):
                raise ValidationFailed(
                    "Please give consent before sharing this optional information.",
                    missing_consent=kind,
                )
            if field in data and data[field] == "":
                data[field] = None

        if "location" in data:
            loc = data.pop("location")
            if loc is None:
                profile.location_lat = profile.location_lng = None
            else:
                profile.location_lat, profile.location_lng = (
                    _coarse(loc["lat"]),
                    _coarse(loc["lng"]),
                )

        declaration = data.pop("married_declaration", None)
        for field in EDITABLE:
            if field in data:
                setattr(profile, field, data[field])
        if declaration:
            profile.married_declaration_at = profile.married_declaration_at or timezone.now()
        elif declaration is False:
            profile.married_declaration_at = None

        _validate_married_rules(profile, account, data)
        if profile.district != "abroad":
            profile.diaspora_country = ""
        elif profile.diaspora_country and (
            len(profile.diaspora_country) != 2 or not profile.diaspora_country.isalpha()
        ):
            raise ValidationFailed("Use a 2-letter country code.")
        profile.diaspora_country = profile.diaspora_country.upper()

        profile.completeness = completeness_of(profile)
        try:
            profile.save()
        except IntegrityError as exc:  # pragma: no cover - defensive
            raise Conflict("Profile update conflict.") from exc
    return profile


def _validate_married_rules(profile: Profile, account: "Account", data: dict[str, Any]) -> None:
    """BR-MAR-01 (PENDING OD-03): married statuses are allowed only for men resident in Uganda who
    declared the marriage is customary/Islamic (not converted to a church/civil marriage), and who gave
    `married_visibility` consent. Opting in to see married profiles needs the same consent.
    QUESTION (product): confirm the consent gating on both; Bible §7.3 only names the declaration."""
    has_consent = account_selectors.has_consent(account, "married_visibility")
    if data.get("show_married_profiles") is True and not has_consent:
        raise ValidationFailed(
            "Please give consent before opting in to see married profiles.",
            missing_consent="married_visibility",
        )
    if profile.marital_status not in MARRIED:
        profile.married_declaration_at = None
        return
    if (
        not settings.MARRIED_PROFILES_ENABLED
        or profile.gender != Profile.Gender.MALE
        or selectors.residence_country(profile) != "UG"
        or profile.married_declaration_at is None
        or not has_consent
    ):
        raise MarriedNotEligible("This marital status can't be used on your profile.")


# ---- completeness (fields part; photos/description/questionnaire join in MC-051) -------------
REQUIRED_FIELDS = (
    "display_name",
    "gender",
    "district",
    "intention",
    "marriage_timeline",
    "marital_status",
)
OPTIONAL_FIELDS = (
    "marriage_form_preference", "has_children", "wants_children", "languages", "occupation", "education",
)  # fmt: skip


def completeness_of(profile: Profile) -> int:
    """0–100 from profile fields only: required fields carry 60 points, optional fields 40."""
    req = sum(1 for f in REQUIRED_FIELDS if getattr(profile, f))
    opt = sum(1 for f in OPTIONAL_FIELDS if getattr(profile, f))
    return round(60 * req / len(REQUIRED_FIELDS) + 40 * opt / len(OPTIONAL_FIELDS))


def clear_special_data(*, account_id: uuid.UUID, kind: str) -> None:
    """Consent withdrawn → delete the special values (they also leave scoring)."""
    if kind == "special_religion":
        Profile.objects.filter(account_id=account_id).update(
            religion=None, religion_practice=None, updated_at=timezone.now()
        )
    elif kind == "married_visibility":
        Profile.objects.filter(account_id=account_id).update(
            show_married_profiles=False, updated_at=timezone.now()
        )

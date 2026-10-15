"""Profile writes (Bible §7.3, §10.3)."""

import unicodedata
import uuid
from decimal import ROUND_HALF_UP, Decimal
from typing import TYPE_CHECKING, Any

from django.conf import settings
from django.db import IntegrityError, transaction
from django.utils import timezone

from mc.accounts import selectors as account_selectors
from mc.beta import services as beta_services
from mc.common import events
from mc.common.errors import (
    Conflict,
    MarriedNotEligible,
    NotVerified,
    ProfileIncomplete,
    ValidationFailed,
)
from mc.verification import selectors as verification_selectors

from . import preferences, readiness, selectors
from .districts import VALID_DISTRICTS
from .events import ProfileWentLive, ProfileWentOffline
from .models import Profile
from .names import normalise_display_name

if TYPE_CHECKING:
    from mc.accounts.models import Account

    from .models import Description

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

        profile.completeness = readiness.completeness(profile)
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


# ---- descriptions (MC-049) --------------------------------------------------------------------
def submit_description(*, account: "Account", text: str) -> "Description":
    """Create the next immutable version and screen it. Approved → becomes the shown description;
    borderline → pending human review; clear violation → rejected with a reason code (and the
    caller returns 422). A newer submission supersedes an older pending one."""
    from mc.common.errors import DescriptionRejected

    from .models import Description
    from .text_screen import APPROVE, REJECT, RULESET_VERSION, screen

    get_or_create_profile(account=account)
    text = unicodedata.normalize("NFKC", text).strip()
    if not settings.DESCRIPTION_MIN <= len(text) <= settings.DESCRIPTION_MAX:
        raise ValidationFailed(
            f"Your description must be {settings.DESCRIPTION_MIN}-{settings.DESCRIPTION_MAX} characters.",
            min_length=settings.DESCRIPTION_MIN,
            max_length=settings.DESCRIPTION_MAX,
        )
    verdict = screen(text)
    with transaction.atomic():
        profile = Profile.objects.select_for_update().get(account=account)
        last = profile.descriptions.order_by("-version").first()
        profile.descriptions.filter(status=Description.Status.PENDING).update(
            status=Description.Status.REJECTED, reject_reason="superseded"
        )
        status = {
            APPROVE: Description.Status.APPROVED,
            REJECT: Description.Status.REJECTED,
        }.get(verdict.outcome, Description.Status.PENDING)
        desc = Description.objects.create(
            profile=profile,
            version=(last.version + 1) if last else 1,
            text=text,
            status=status,
            reject_reason=verdict.reason if status != Description.Status.APPROVED else "",
            ruleset_version=RULESET_VERSION,
        )
        if status == Description.Status.APPROVED:
            _make_current(profile, desc)
    if status == Description.Status.REJECTED:
        raise DescriptionRejected(
            "Your description can't include contact details, links or requests for money.",
            reason=desc.reject_reason,
            description_id=str(desc.id),
            version=desc.version,
        )
    return desc


def _make_current(profile: Profile, desc: "Description") -> None:
    profile.current_description = desc
    profile.save(update_fields=["current_description", "updated_at"])
    refresh(profile)


def review_description(
    *, description_id: uuid.UUID, approve: bool, reviewer_id: uuid.UUID, reason: str = ""
) -> "Description":
    """Human decision on a pending description (admin queue). Audited by the admin layer."""
    from .models import Description

    with transaction.atomic():
        desc = (
            Description.objects.select_for_update().select_related("profile").get(id=description_id)
        )
        if desc.status != Description.Status.PENDING:
            raise Conflict("This description was already decided.")
        desc.status = Description.Status.APPROVED if approve else Description.Status.REJECTED
        desc.reject_reason = "" if approve else (reason or "rejected_by_reviewer")[:40]
        desc.reviewed_by = reviewer_id
        desc.save(update_fields=["status", "reject_reason", "reviewed_by", "updated_at"])
        if approve:
            _make_current(desc.profile, desc)
    return desc


# ---- readiness, go-live, visibility (MC-051) -----------------------------------------------------
def refresh(profile: Profile) -> Profile:
    """Recompute completeness; take a live profile offline if it no longer meets the go-live rules
    (e.g. its photo count dropped below the minimum)."""
    profile.completeness = readiness.completeness(profile)
    fields = ["completeness", "updated_at"]
    went_offline = False
    if profile.status == Profile.Status.LIVE and readiness.missing_for_go_live(profile):
        profile.status = Profile.Status.DRAFT
        fields.append("status")
        went_offline = True
    profile.save(update_fields=fields)
    if went_offline:
        events.publish(
            ProfileWentOffline(
                account_id=profile.account_id, profile_id=profile.id, reason="requirements"
            )
        )
    return profile


def go_live(*, account: "Account") -> Profile:
    """Draft → live only when every §10.3 rule holds; otherwise `profile_incomplete` lists what's missing."""
    profile = get_or_create_profile(account=account)
    with transaction.atomic():
        profile = Profile.objects.select_for_update().get(pk=profile.pk)
        if profile.status == Profile.Status.SUSPENDED:
            raise Conflict("This profile is suspended.")
        if profile.status == Profile.Status.LIVE:
            return profile  # idempotent
        missing = readiness.missing_for_go_live(profile)
        if missing:
            raise ProfileIncomplete("Your profile isn't ready yet.", missing=missing)
        beta_services.claim_go_live(district=profile.district)
        profile.status = Profile.Status.LIVE
        profile.completeness = readiness.completeness(profile)
        profile.save(update_fields=["status", "completeness", "updated_at"])
        preferences.get_or_create_preference(profile=profile)  # discovery needs a preference row
        events.publish(ProfileWentLive(account_id=account.id, profile_id=profile.id))
    return profile


def set_hidden(*, account: "Account", hidden: bool) -> Profile:
    profile = get_or_create_profile(account=account)
    with transaction.atomic():
        profile = Profile.objects.select_for_update().get(pk=profile.pk)
        if profile.status == Profile.Status.SUSPENDED:
            raise Conflict("This profile is suspended.")
        if hidden and profile.status == Profile.Status.LIVE:
            profile.status = Profile.Status.HIDDEN_BY_USER
            events.publish(
                ProfileWentOffline(
                    account_id=account.id, profile_id=profile.id, reason="hidden_by_user"
                )
            )
        elif not hidden and profile.status == Profile.Status.HIDDEN_BY_USER:
            if readiness.missing_for_go_live(profile):
                profile.status = Profile.Status.DRAFT
            else:
                profile.status = Profile.Status.LIVE
                events.publish(ProfileWentLive(account_id=account.id, profile_id=profile.id))
        profile.save(update_fields=["status", "updated_at"])
    return profile


# ---- enforcement hooks (safety module) ------------------------------------------------------------
def suspend_profile(*, account_id: uuid.UUID) -> None:
    """Hide the profile everywhere (discovery, views, photos) until reinstated."""
    profile = Profile.objects.filter(account_id=account_id).first()
    if profile is not None and profile.status != Profile.Status.SUSPENDED:
        profile.status = Profile.Status.SUSPENDED
        profile.save(update_fields=["status", "updated_at"])
        events.publish(
            ProfileWentOffline(account_id=account_id, profile_id=profile.id, reason="suspended")
        )


def restore_profile(*, account_id: uuid.UUID) -> None:
    """After reinstatement: back to draft, then live again if every go-live rule still holds."""
    profile = Profile.objects.filter(account_id=account_id, status=Profile.Status.SUSPENDED).first()
    if profile is None:
        return
    profile.status = (
        Profile.Status.LIVE if not readiness.missing_for_go_live(profile) else Profile.Status.DRAFT
    )
    profile.save(update_fields=["status", "updated_at"])

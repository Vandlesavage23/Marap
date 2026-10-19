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
    Underage,
    ValidationFailed,
)
from mc.common.timeutil import age_on, kampala_date
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
    "photo_visibility",
)  # fmt: skip
MAX_DECLARED_AGE = 100


def get_or_create_profile(*, account: "Account", allow_unverified: bool = False) -> Profile:
    """Profile building needs a verified adult: `birth_date` comes from the passed verification (and replaces any
    date declared earlier). `allow_unverified=True` only RETURNS the "About you" profile an unverified member
    already has; it never creates one (that is `update_profile`'s job, with a declared birth date)."""
    dob = verification_selectors.verified_date_of_birth(account)
    if dob is None:
        existing = Profile.objects.filter(account=account).first() if allow_unverified else None
        if existing is None:
            raise NotVerified("Verify your identity before building your profile.")
        return existing
    profile, created = Profile.objects.get_or_create(
        account=account,
        defaults={
            "birth_date": dob,
            "show_married_profiles": settings.MARRIED_VISIBILITY_DEFAULT,
        },
    )
    if not created and profile.birth_date != dob:
        profile.birth_date = dob
        profile.save(update_fields=["birth_date", "updated_at"])
    return profile


def open_profile(
    *,
    viewer: "Account",
    target: Profile,
    now: Any = None,
    ip: str | None = None,
    install_id: str | None = None,
) -> bool:
    """Gate and count one profile open. Returns True when the viewer gets the LIMITED (locked) payload, i.e. they
    have not verified their identity. Unverified viewers need the required consents, are held to
    PROFILE_OPENS_PER_DAY_UNVERIFIED distinct profiles per Kampala day (429 `limit_reached` + `resets_at`) and to
    per-IP/device caps. Opening your own profile or being verified costs nothing."""
    from mc.accounts import services as account_services
    from mc.common import quota, ratelimit
    from mc.common.errors import LimitReached
    from mc.common.timeutil import iso_z, next_kampala_midnight
    from mc.entitlements import selectors as entitlement_selectors

    if target.account_id == viewer.id:
        return False
    now = now or timezone.now()
    summary = entitlement_selectors.entitlement_summary(viewer, now)
    if summary.capabilities["view_full_profile"]:
        return False
    account_services.require_verification_consents(viewer)
    ratelimit.hit_client(
        "open",
        ip=ip,
        install_id=install_id,
        limit=settings.PROFILE_OPENS_PER_IP_PER_DAY_UNVERIFIED,
        window_seconds=24 * 3600,
    )
    limit = entitlement_selectors.profile_open_limit(summary)
    if limit is not None and not quota.consume_unique(
        quota.day_key("open", viewer.id, now), member=target.id, limit=limit, now=now
    ):
        resets = next_kampala_midnight(now)
        raise LimitReached(
            "You've opened as many profiles as you can today without verifying. "
            "Verify your identity to see more, or come back tomorrow.",
            resets_at=iso_z(resets),
            limit=limit,
            retry_after=max(int((resets - now).total_seconds()), 1),
        )
    return True


def adopt_verified_birth_date(*, account_id: uuid.UUID) -> None:
    """The identity check passed: the ID's date of birth replaces whatever the member declared at sign-up."""
    from mc.accounts.selectors import get_account

    account = get_account(account_id)
    dob = verification_selectors.verified_date_of_birth(account) if account else None
    if dob is not None:
        Profile.objects.filter(account_id=account_id).exclude(birth_date=dob).update(
            birth_date=dob, updated_at=timezone.now()
        )


def _check_declared_birth_date(value: Any) -> None:
    age = age_on(value, kampala_date(timezone.now()))
    if age < settings.MIN_AGE:
        raise Underage(
            f"Marriage Connect is for adults aged {settings.MIN_AGE} or over. "
            "Please check the date you entered."
        )
    if age > MAX_DECLARED_AGE:
        raise ValidationFailed("Please check your birth date.")


def _coarse(value: Any, places: str = "0.01") -> Decimal:
    return Decimal(str(value)).quantize(Decimal(places), rounding=ROUND_HALF_UP)


def _ensure_profile_for_update(account: "Account", data: dict[str, Any]) -> bool:
    """Create the draft profile if needed (outside the update txn: a rejected PATCH keeps the draft). Verified
    members get it with their ID's birth date; an unverified member creates it with the birth date they declare in
    "About you" (18+ only). Returns whether the account is verified."""
    verified = verification_selectors.verified_date_of_birth(account) is not None
    if verified:
        get_or_create_profile(account=account)
        return True
    if Profile.objects.filter(account=account).exists():
        return False
    declared = data.get("birth_date")
    if declared is None:
        raise ValidationFailed("Tell us your birth date to get started.", missing=["birth_date"])
    _check_declared_birth_date(declared)
    Profile.objects.get_or_create(
        account=account,
        defaults={
            "birth_date": declared,
            "show_married_profiles": settings.MARRIED_VISIBILITY_DEFAULT,
        },
    )
    return False


def update_profile(*, account: "Account", data: dict[str, Any]) -> Profile:
    """Apply a partial update, validating every rule in §7.3. All-or-nothing."""
    unknown = set(data) - set(EDITABLE) - {"married_declaration", "location", "birth_date"}
    if unknown:
        raise ValidationFailed(f"Unknown fields: {', '.join(sorted(unknown))}")
    verified = _ensure_profile_for_update(account, data)
    with transaction.atomic():
        profile = Profile.objects.select_for_update().get(account=account)
        if profile.status == Profile.Status.SUSPENDED:
            raise Conflict("This profile is suspended.")

        if "birth_date" in data:
            declared = data.pop("birth_date")
            if verified:
                if declared != profile.birth_date:
                    raise ValidationFailed(
                        "Your birth date comes from your ID and can't be changed.", locked=True
                    )
            else:
                _check_declared_birth_date(declared)
                profile.birth_date = declared
        if "photo_visibility" in data and data["photo_visibility"] not in (
            Profile.PhotoVisibility.values
        ):
            raise ValidationFailed("Choose who can see your photos: everyone or verified members.")

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
    profile = get_or_create_profile(
        account=account
    )  # NotVerified until the identity check has passed
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

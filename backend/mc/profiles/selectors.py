import uuid
from datetime import date

from django.utils import timezone

from mc.accounts import selectors as account_selectors
from mc.common.timeutil import age_on, kampala_date
from mc.verification import selectors as verification_selectors

from .models import Profile


def get_profile_for_account(account_id: uuid.UUID) -> Profile | None:
    return Profile.objects.filter(account_id=account_id).first()


def age_of(profile: Profile, on: date | None = None) -> int:
    return age_on(profile.birth_date, on or kampala_date(timezone.now()))


def residence_country(profile: Profile) -> str:
    """UG for in-country profiles; the declared diaspora country when abroad."""
    return profile.diaspora_country if profile.district == "abroad" else "UG"


def has_special_consent(account, kind: str) -> bool:  # type: ignore[no-untyped-def]
    return account_selectors.has_consent(account, kind)


def is_verified(account) -> bool:  # type: ignore[no-untyped-def]
    return verification_selectors.is_verified_adult(account)


def current_description(profile: Profile):  # type: ignore[no-untyped-def]
    return profile.current_description


def has_approved_description(account_id: uuid.UUID) -> bool:
    return Profile.objects.filter(account_id=account_id, current_description__isnull=False).exists()


def approved_photos(profile: Profile):  # type: ignore[no-untyped-def]
    return (
        profile.photos.filter(moderation_status="approved")
        .select_related("media")
        .order_by("position")
    )


def readiness(profile: Profile) -> dict[str, object]:
    from . import readiness as r

    missing = r.missing_for_go_live(profile)
    return {"ready": not missing, "missing": missing}

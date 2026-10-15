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

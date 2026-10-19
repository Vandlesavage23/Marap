from typing import TYPE_CHECKING, Any

from django.conf import settings
from django.db import transaction

from mc.common.errors import ValidationFailed

from . import selectors
from .models import Preference, Profile

if TYPE_CHECKING:
    from mc.accounts.models import Account

FIELDS = ("age_min", "age_max", "max_distance_km", "include_diaspora", "accept_has_children")


def default_age_window(profile: Profile) -> dict[str, int]:
    """The age range a member gets until they choose one: a few years younger to a few older, clamped to 18-80."""
    age = selectors.age_of(profile)
    age_max = min(80, max(18, age + settings.PREFERENCE_DEFAULT_AGE_ABOVE))
    return {
        "age_min": min(max(18, age - settings.PREFERENCE_DEFAULT_AGE_BELOW), age_max),
        "age_max": age_max,
    }


def derived_preference(profile: Profile) -> Preference:
    """Unsaved default preference (opposite gender is implicit in discovery; age window from the birth date) for a
    viewer who has not set preferences, e.g. a member browsing before they have a live profile."""
    return Preference(profile=profile, **default_age_window(profile))


def get_or_create_preference(*, profile: Profile) -> Preference:
    pref, _ = Preference.objects.get_or_create(profile=profile, defaults=default_age_window(profile))
    return pref


def set_preferences(*, account: "Account", data: dict[str, Any]) -> Preference:
    from . import services

    unknown = set(data) - set(FIELDS)
    if unknown:
        raise ValidationFailed(f"Unknown fields: {', '.join(sorted(unknown))}")
    profile = services.get_or_create_profile(account=account)
    with transaction.atomic():
        pref = Preference.objects.select_for_update().filter(
            profile=profile
        ).first() or get_or_create_preference(profile=profile)
        for f in FIELDS:
            if f in data:
                setattr(pref, f, data[f])
        if not (18 <= pref.age_min <= pref.age_max <= 80):
            raise ValidationFailed(
                "Choose an age range between 18 and 80 (minimum no higher than maximum)."
            )
        if pref.max_distance_km is not None and not 1 <= pref.max_distance_km <= 2000:
            raise ValidationFailed("Maximum distance must be between 1 and 2000 km.")
        pref.save()
    return pref

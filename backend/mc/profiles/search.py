"""Hard-filter candidate search (Bible §10.6 step 1). One SQL query over profiles + preferences; the
discovery module calls `hard_filter_candidates` and never touches profile tables itself.

Deal-breakers are NOT here: they depend on questionnaire answers (some encrypted) and are applied by
discovery on the returned batch.
"""

import uuid
from dataclasses import dataclass
from datetime import date
from typing import Any

from django.conf import settings
from django.db.models import F, FloatField, Q, QuerySet
from django.db.models.functions import ACos, Cast, Cos, Least, Radians, Sin
from django.utils import timezone

from mc.common.timeutil import kampala_date

from . import selectors
from .models import Preference, Profile

MARRIED = ("married_customary", "married_islamic")
EARTH_KM = 6371.0


@dataclass(frozen=True)
class ViewerContext:
    account_id: uuid.UUID
    profile_id: uuid.UUID
    gender: str
    age: int
    district: str
    lat: float | None
    lng: float | None
    show_married_profiles: bool
    married: bool
    has_children: str
    age_min: int
    age_max: int
    max_distance_km: int | None
    include_diaspora: bool
    accept_has_children: bool


def viewer_context(profile: Profile, pref: Preference) -> ViewerContext:
    return ViewerContext(
        account_id=profile.account_id,
        profile_id=profile.id,
        gender=profile.gender,
        age=selectors.age_of(profile),
        district=profile.district,
        lat=float(profile.location_lat) if profile.location_lat is not None else None,
        lng=float(profile.location_lng) if profile.location_lng is not None else None,
        show_married_profiles=profile.show_married_profiles,
        married=profile.marital_status in MARRIED,
        has_children=profile.has_children,
        age_min=pref.age_min,
        age_max=pref.age_max,
        max_distance_km=pref.max_distance_km,
        include_diaspora=pref.include_diaspora,
        accept_has_children=pref.accept_has_children,
    )


def birth_date_for_age(today: date, years: int) -> date:
    """Latest birth date for someone who is at least `years` old today (consistent with `age_on`)."""
    try:
        return today.replace(year=today.year - years)
    except ValueError:  # Feb 29 in a leap year → the non-leap year has no Feb 29
        return today.replace(year=today.year - years, day=28)


def _distance_km(lat: float, lng: float) -> Any:
    from django.db.models import Value

    return EARTH_KM * ACos(
        Least(
            1.0,
            Cos(Radians(Value(lat)))
            * Cos(Radians(Cast("location_lat", FloatField())))
            * Cos(Radians(Cast("location_lng", FloatField())) - Radians(Value(lng)))
            + Sin(Radians(Value(lat))) * Sin(Radians(Cast("location_lat", FloatField()))),
        )
    )


def candidate_queryset(v: ViewerContext, *, today: date | None = None) -> QuerySet[Profile]:
    today = today or kampala_date(timezone.now())
    qs = (
        Profile.objects.filter(
            status=Profile.Status.LIVE, account__status="active", preference__isnull=False
        )
        .exclude(account_id=v.account_id)
        .exclude(gender="")
        .exclude(gender=v.gender)  # opposite-gender matching only
    )
    # age: candidate within viewer's range AND viewer within candidate's range
    qs = qs.filter(
        birth_date__lte=birth_date_for_age(today, v.age_min),
        birth_date__gt=birth_date_for_age(today, v.age_max + 1),
        preference__age_min__lte=v.age,
        preference__age_max__gte=v.age,
    )
    # married profiles (BR-MAR-01 / PENDING OD-03), both directions
    if not settings.MARRIED_PROFILES_ENABLED:
        qs = qs.exclude(marital_status__in=MARRIED)
        if v.married:
            return qs.none()
    else:
        if not v.show_married_profiles:
            qs = qs.exclude(marital_status__in=MARRIED)
        if v.married:
            qs = qs.filter(show_married_profiles=True)
    # diaspora
    if not v.include_diaspora:
        qs = qs.exclude(district="abroad")
    if v.district == "abroad":
        qs = qs.filter(preference__include_diaspora=True)
    # distance (only when both sides have a coarse location; unknown location is not excluded)
    if v.max_distance_km and v.lat is not None and v.lng is not None and v.district != "abroad":
        qs = qs.filter(
            Q(district="abroad")
            | Q(location_lat__isnull=True)
            | Q(location_lng__isnull=True)
            | Q(pk__in=Profile.objects.filter(location_lat__isnull=False, location_lng__isnull=False)
                .annotate(d=_distance_km(v.lat, v.lng)).filter(d__lte=v.max_distance_km).values("pk"))
        )  # fmt: skip
    # children (both directions)
    if not v.accept_has_children:
        qs = qs.filter(has_children__in=["no", ""])
    if v.has_children not in ("no", ""):
        qs = qs.filter(preference__accept_has_children=True)
    return qs


def hard_filter_candidates(
    v: ViewerContext, *, exclude_account_ids: set[uuid.UUID], limit: int, today: date | None = None
) -> list[dict[str, Any]]:
    qs = candidate_queryset(v, today=today)
    if exclude_account_ids:
        qs = qs.exclude(account_id__in=exclude_account_ids)
    rows = qs.order_by(F("account__last_seen_at").desc(nulls_last=True), "id").values(
        "id", "account_id", "district", "created_at"
    )[:limit]
    return [dict(r) for r in rows]

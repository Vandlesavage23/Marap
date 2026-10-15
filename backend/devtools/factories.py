"""Test/demo factories (MC-023). Build fully consistent members directly through the ORM — verified
identity, live profile, preferences, photos, description, answers — without the HTTP flow.

Never imported by production code paths; `seed_demo` refuses to run outside local/dev."""

import itertools
import random
import uuid
from datetime import date, datetime, timedelta
from typing import Any

from django.utils import timezone

from mc.accounts.models import Account
from mc.common.crypto import hmac_value
from mc.common.ids import uuid7
from mc.media.models import MediaObject
from mc.profiles.districts import UGANDA_DISTRICTS
from mc.profiles.models import Description, Photo, Preference, Profile
from mc.questionnaire.models import Answer, Question
from mc.verification.models import VerificationAttempt

_phone_counter = itertools.count(1)
_name_counter = itertools.count(1)
DESCRIPTION = (
    "I am a kind and hardworking person who loves family, faith and simple joys like cooking and long walks. "
    "I am looking for an honest partner who is ready to build a home together and grow side by side in life."
)


def next_phone() -> str:
    n = next(_phone_counter)
    return f"+25677{n % 10_000_000:07d}" if n < 10_000_000 else f"+25670{n % 10_000_000:07d}"


def age_to_dob(age: int, today: date | None = None) -> date:
    today = today or timezone.localdate()
    return (
        date(today.year - age, 1, 15)
        if (today.month, today.day) >= (1, 15)
        else date(today.year - age - 1, 1, 15)
    )


def answers_for(
    values: dict[str, Any], *, importance: int = 2, dealbreakers: tuple[str, ...] = ()
) -> dict[str, Any]:
    return {"values": values, "importance": importance, "dealbreakers": dealbreakers}


def default_answer_values(rng: random.Random | None = None) -> dict[str, Any]:
    rng = rng or random.Random(1)
    out: dict[str, Any] = {}
    for q in Question.objects.filter(is_core=True, active=True):
        if q.type == "single":
            out[q.key] = rng.choice(q.options)["value"]
        elif q.type == "multi":
            out[q.key] = [rng.choice(q.options)["value"]]
        else:
            out[q.key] = rng.randint(q.options["min"], q.options["max"])
    return out


def create_member(
    *,
    gender: str = "female",
    age: int = 28,
    district: str = "Kampala",
    name: str | None = None,
    live: bool = True,
    verified: bool = True,
    phone: str | None = None,
    answer_values: dict[str, Any] | None = None,
    importance: int = 2,
    dealbreakers: tuple[str, ...] = (),
    age_min: int | None = None,
    age_max: int | None = None,
    max_distance_km: int | None = None,
    include_diaspora: bool = True,
    accept_has_children: bool = True,
    marital_status: str = "never_married",
    show_married_profiles: bool = False,
    has_children: str = "no",
    lat: float | None = None,
    lng: float | None = None,
    created_at: datetime | None = None,
    last_seen_at: datetime | None = None,
    photos: int = 2,
    with_answers: bool = True,
    diaspora_country: str = "",
) -> Account:
    account = Account.objects.create(
        phone_e164=phone or next_phone(),
        status="active" if verified else "pending_verification",
        last_seen_at=last_seen_at,
    )
    if verified:
        VerificationAttempt.objects.create(
            account=account,
            vendor_job_id=f"fx_{uuid.uuid4().hex}",
            status="passed",
            id_type="NATIONAL_ID",
            issuing_country="UG",
            date_of_birth=age_to_dob(age),
            id_number_hmac=hmac_value(f"fx-{account.id}", purpose="id_number"),
            decided_at=timezone.now(),
        )
    profile = Profile.objects.create(
        account=account,
        display_name=name or f"Member {next(_name_counter)}",
        gender=gender,
        birth_date=age_to_dob(age),
        district=district,
        diaspora_country=diaspora_country,
        location_lat=lat,
        location_lng=lng,
        intention="marriage_soon",
        marriage_timeline="1_2y",
        marital_status=marital_status,
        married_declaration_at=timezone.now() if marital_status.startswith("married") else None,
        show_married_profiles=show_married_profiles,
        has_children=has_children,
        wants_children="yes",
        languages=["en"],
        status=Profile.Status.LIVE if live else Profile.Status.DRAFT,
        completeness=80,
    )
    if created_at:
        Profile.objects.filter(pk=profile.pk).update(created_at=created_at)
    Preference.objects.create(
        profile=profile,
        age_min=age_min if age_min is not None else max(18, age - 7),
        age_max=age_max if age_max is not None else min(80, age + 10),
        max_distance_km=max_distance_km,
        include_diaspora=include_diaspora,
        accept_has_children=accept_has_children,
    )
    desc = Description.objects.create(
        profile=profile, version=1, text=DESCRIPTION, status="approved"
    )
    Profile.objects.filter(pk=profile.pk).update(current_description=desc)
    for pos in range(photos):
        mid = uuid.uuid4()
        media = MediaObject.objects.create(
            id=mid, owner=account, purpose="profile_photo", declared_mime="image/jpeg", declared_bytes=1000,
            upload_key=f"uploads/{account.id}/{mid}", storage_key=f"media/{account.id}/{mid}.webp",
            mime="image/webp", bytes=900, width=800, height=1000, status="ready", moderation="approved", face_count=1,
        )  # fmt: skip
        Photo.objects.create(
            profile=profile,
            media=media,
            position=pos,
            moderation_status="approved",
            face_match=True,
        )
    if with_answers:
        save_answers(
            account,
            answer_values or default_answer_values(),
            importance=importance,
            dealbreakers=dealbreakers,
        )
    return account


def save_answers(
    account: Account,
    values: dict[str, Any],
    *,
    importance: int = 2,
    dealbreakers: tuple[str, ...] = (),
) -> None:
    questions = {q.key: q for q in Question.objects.filter(key__in=list(values))}
    rows = []
    for key, value in values.items():
        q = questions[key]
        rows.append(
            Answer(
                account=account,
                question=q,
                question_version=q.version,
                value=value,
                importance=importance,
                is_dealbreaker=key in dealbreakers,
            )
        )
    Answer.objects.bulk_create(
        rows,
        update_conflicts=True,
        unique_fields=["account", "question"],
        update_fields=["value", "importance", "is_dealbreaker", "question_version"],
    )


def random_district(rng: random.Random) -> str:
    return rng.choice(UGANDA_DISTRICTS)


__all__ = [
    "create_member",
    "default_answer_values",
    "next_phone",
    "save_answers",
    "timedelta",
    "uuid7",
]

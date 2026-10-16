import uuid
from datetime import date, datetime, timedelta

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


def viewer_context_for(account):  # type: ignore[no-untyped-def]
    """Search context for a live viewer, or None when the viewer has no live profile."""
    from . import preferences
    from .search import viewer_context

    profile = Profile.objects.filter(account=account, status=Profile.Status.LIVE).first()
    if profile is None:
        return None
    return viewer_context(profile, preferences.get_or_create_preference(profile=profile))


def card_data(profile_ids, viewer) -> dict[uuid.UUID, dict[str, object]]:  # type: ignore[no-untyped-def]
    """CandidateCard basics (no numeric score) for profiles that are still live+active, keyed by profile id.
    Includes signed photo URLs for approved photos only.

    Batched: one query for profiles, one for all their approved photos (+media), and the viewer-side photo
    policy facts (blocks, gender, `browse`) read once. A photo the batched check does not clear falls back to
    the full per-media policy (`media.selectors.signed_url`), so interest/match grants still apply."""
    from collections import defaultdict

    from mc.media import selectors as media_selectors

    from .constants import MARITAL_LABELS
    from .models import Photo
    from .policies import BatchedProfileAccess

    out: dict[uuid.UUID, dict[str, object]] = {}
    profiles = list(
        Profile.objects.filter(
            id__in=list(profile_ids), status=Profile.Status.LIVE, account__status="active"
        )
    )
    if not profiles:
        return out
    photos_by_profile: dict[uuid.UUID, list[Photo]] = defaultdict(list)
    for ph in (
        Photo.objects.filter(profile_id__in=[p.id for p in profiles], moderation_status="approved")
        .select_related("media")
        .order_by("profile_id", "position")
    ):
        photos_by_profile[ph.profile_id].append(ph)
    access = BatchedProfileAccess(viewer)
    for p in profiles:
        photos = []
        for ph in photos_by_profile.get(p.id, []):
            url = (
                media_selectors.signed_url_prechecked(ph.media)
                if access.can_view(p)
                else media_selectors.signed_url(ph.media, viewer)
            )
            photos.append({"url": url, "w": ph.media.width, "h": ph.media.height})
        out[p.id] = {
            "profile_id": str(p.id),
            "display_name": p.display_name,
            "age": age_of(p),
            "district": p.district,
            "photos": photos,
            "intention": p.intention,
            "marriage_timeline": p.marriage_timeline,
            "marital_status_label": MARITAL_LABELS[p.marital_status]
            if p.marital_status.startswith("married")
            else None,
            "badges": [
                "age_verified",
                "identity_verified",
                *(["photo_verified"] if photos else []),
            ],
        }
    return out


def account_id_for_profile(profile_id: uuid.UUID) -> uuid.UUID | None:
    return Profile.objects.filter(id=profile_id).values_list("account_id", flat=True).first()


def live_profile_attributes() -> list[dict[str, object]]:
    """`[{account_id, gender, age, district}]` for every live profile (evaluation reports only)."""
    return [
        {"account_id": p.account_id, "gender": p.gender, "age": age_of(p), "district": p.district}
        for p in Profile.objects.filter(status=Profile.Status.LIVE, account__status="active").only(
            "account_id", "gender", "birth_date", "district"
        )
    ]


def profile_id_for_account(account_id: uuid.UUID) -> uuid.UUID | None:
    return Profile.objects.filter(account_id=account_id).values_list("id", flat=True).first()


def member_summaries(account_ids, viewer) -> dict[uuid.UUID, dict[str, object]]:  # type: ignore[no-untyped-def]
    """`{account_id: summary}` for interest lists: public handle = profile id; first approved photo (signed URL
    only if the media policy lets `viewer` see it)."""
    from django.conf import settings
    from django.utils import timezone

    from mc.media import selectors as media_selectors

    from .constants import MARITAL_LABELS

    out: dict[uuid.UUID, dict[str, object]] = {}
    for p in Profile.objects.filter(account_id__in=list(account_ids)):
        first = approved_photos(p).first()
        url = media_selectors.signed_url(first.media, viewer) if first else None
        out[p.account_id] = {
            "id": str(p.id),
            "display_name": p.display_name,
            "age": age_of(p),
            "district": p.district,
            "verified": {"age": True, "identity": True, "photos": first is not None},
            "marital_status_label": MARITAL_LABELS[p.marital_status]
            if p.marital_status.startswith("married")
            else None,
            "primary_photo": (
                {
                    "url": url,
                    "expires_at": timezone.now()
                    + timedelta(seconds=settings.MEDIA_SIGNED_URL_SECONDS),
                }
                if url
                else None
            ),
        }
    return out


def is_approved_photo_media(media) -> bool:  # type: ignore[no-untyped-def]
    from .models import Photo

    return Photo.objects.filter(media=media, moderation_status=Photo.Moderation.APPROVED).exists()


def report_snapshot(profile_id: uuid.UUID) -> dict[str, object] | None:
    """Frozen copy of a profile for report evidence (what a moderator needs, nothing private)."""
    p = Profile.objects.select_related("current_description").filter(id=profile_id).first()
    if p is None:
        return None
    return {
        "profile_id": str(p.id),
        "display_name": p.display_name,
        "age": age_of(p),
        "district": p.district,
        "intention": p.intention,
        "marital_status": p.marital_status,
        "occupation": p.occupation,
        "description": p.current_description.text if p.current_description else None,
        "photo_media_ids": [str(ph.media_id) for ph in approved_photos(p)],
    }


def status_for(account) -> str:  # type: ignore[no-untyped-def]
    """`none` before a profile exists, else draft | live | hidden_by_user | suspended."""
    status = Profile.objects.filter(account=account).values_list("status", flat=True).first()
    return status or "none"


def export_for_account(account) -> dict[str, object]:  # type: ignore[no-untyped-def]
    p = Profile.objects.filter(account=account).first()
    if p is None:
        return {}
    pref = getattr(p, "preference", None) if hasattr(p, "preference") else None
    return {
        "display_name": p.display_name,
        "gender": p.gender,
        "birth_date": p.birth_date.isoformat(),
        "district": p.district,
        "diaspora_country": p.diaspora_country,
        "intention": p.intention,
        "marriage_timeline": p.marriage_timeline,
        "marital_status": p.marital_status,
        "has_children": p.has_children,
        "wants_children": p.wants_children,
        "languages": p.languages,
        "religion": p.religion,
        "religion_practice": p.religion_practice,
        "occupation": p.occupation,
        "education": p.education,
        "status": p.status,
        "descriptions": [
            {
                "version": d.version,
                "text": d.text,
                "status": d.status,
                "created_at": d.created_at.isoformat(),
            }
            for d in p.descriptions.order_by("version")
        ],
        "photos": [
            {"position": ph.position, "media_id": str(ph.media_id), "status": ph.moderation_status}
            for ph in p.photos.all()
        ],
        "preferences": (
            {
                "age_min": pref.age_min,
                "age_max": pref.age_max,
                "max_distance_km": pref.max_distance_km,
                "include_diaspora": pref.include_diaspora,
                "accept_has_children": pref.accept_has_children,
            }
            if pref
            else None
        ),
    }


LIVE_LIKE = (Profile.Status.LIVE, Profile.Status.HIDDEN_BY_USER)


def funnel_live_count(*, start: datetime, end: datetime) -> int | None:
    """Dashboard funnel, stage 3: accounts registered in `[start, end)` whose profile is live (or paused by the
    member, which only a live profile can be)."""
    from mc.common.aggregates import suppress

    n = Profile.objects.filter(
        status__in=LIVE_LIKE, account__created_at__gte=start, account__created_at__lt=end
    ).count()
    return suppress(n)


def live_density_by_district() -> list[dict[str, object]]:
    """Dashboard density: live profiles per district (UBOS list + `abroad`), largest first. Cells below the
    suppression threshold come back with `live=None`; no member data of any kind."""
    from django.db.models import Count

    from mc.common.aggregates import suppress

    from .districts import ABROAD, UGANDA_DISTRICTS

    counts = {
        row["district"]: row["n"]
        for row in Profile.objects.filter(status=Profile.Status.LIVE)
        .values("district")
        .annotate(n=Count("id"))
        .order_by()
    }
    names = [*UGANDA_DISTRICTS, ABROAD]
    other = sum(n for d, n in counts.items() if d not in names)  # legacy/blank values
    rows: list[dict[str, object]] = [
        {"district": d, "live": suppress(counts.get(d, 0))} for d in names
    ]
    if other:
        rows.append({"district": "(other)", "live": suppress(other)})
    rows.sort(key=lambda r: (-(r["live"] or 0), str(r["district"])))  # type: ignore[operator]
    return rows

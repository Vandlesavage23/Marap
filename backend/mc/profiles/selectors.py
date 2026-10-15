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
    Includes signed photo URLs for approved photos only."""
    from mc.media import selectors as media_selectors

    from .constants import MARITAL_LABELS

    out: dict[uuid.UUID, dict[str, object]] = {}
    qs = Profile.objects.filter(
        id__in=list(profile_ids), status=Profile.Status.LIVE, account__status="active"
    )
    for p in qs:
        photos = [
            {
                "url": media_selectors.signed_url(ph.media, viewer),
                "w": ph.media.width,
                "h": ph.media.height,
            }
            for ph in approved_photos(p)
        ]
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

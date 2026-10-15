"""Go-live readiness (Bible §10.3) and completeness."""

from django.conf import settings

from mc.questionnaire import selectors as questionnaire_selectors
from mc.verification import selectors as verification_selectors

from .models import Photo, Profile

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


def missing_for_go_live(profile: Profile) -> list[str]:
    missing = [f for f in REQUIRED_FIELDS if not getattr(profile, f)]
    if not verification_selectors.is_verified_adult(profile.account):
        missing.append("verification")
    approved = profile.photos.filter(moderation_status=Photo.Moderation.APPROVED).count()
    if approved < settings.PHOTOS_MIN_APPROVED:
        missing.append("photos")
    if profile.current_description_id is None:
        missing.append("description")
    if not questionnaire_selectors.core_complete(profile.account_id):
        missing.append("questionnaire")
    return missing


def completeness(profile: Profile) -> int:
    """0–100: required items 80 points (fields 30, photos 20, description 15, core answers 15);
    optional 20 (fields 10, extra approved photos 5, optional answers 5)."""
    req_fields = sum(1 for f in REQUIRED_FIELDS if getattr(profile, f))
    points = 30 * req_fields / len(REQUIRED_FIELDS)
    approved = profile.photos.filter(moderation_status=Photo.Moderation.APPROVED).count()
    points += 20 * min(approved, settings.PHOTOS_MIN_APPROVED) / settings.PHOTOS_MIN_APPROVED
    points += 15 if profile.current_description_id else 0
    points += 15 if questionnaire_selectors.core_complete(profile.account_id) else 0
    points += 10 * sum(1 for f in OPTIONAL_FIELDS if getattr(profile, f)) / len(OPTIONAL_FIELDS)
    extra_cap = settings.PHOTOS_MAX - settings.PHOTOS_MIN_APPROVED
    points += 5 * min(max(approved - settings.PHOTOS_MIN_APPROVED, 0), extra_cap) / extra_cap
    points += 5 if questionnaire_selectors.has_optional_answers(profile.account_id) else 0
    return min(round(points), 100)

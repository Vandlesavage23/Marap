"""Go-live readiness (Bible §10.3, v2) and completeness.

v2 (docs/design/user-flow-v2.md §2 row 8): a short go-live. Blocking items are the codes in `missing`; everything
else that makes a profile better is listed in `complete_later` and never blocks. Thresholds are config
(`GO_LIVE_MIN_PHOTOS`, `GO_LIVE_MIN_CORE_ANSWERS`). `marriage_timeline` is optional now; `marital_status` stays
required because the married-status rule (BR-MAR-01 / PENDING OD-03) filters on it: a blank status would let a
married member hide it from people who have not opted in to see married profiles.
"""

from django.conf import settings

from mc.questionnaire import selectors as questionnaire_selectors
from mc.verification import selectors as verification_selectors

from .models import Photo, Profile

REQUIRED_FIELDS = ("display_name", "gender", "district", "intention", "marital_status")
LATER_FIELDS = ("marriage_timeline",)
OPTIONAL_FIELDS = (
    "marriage_form_preference", "has_children", "wants_children", "languages", "occupation", "education",
)  # fmt: skip


def _approved_photos(profile: Profile) -> int:
    return profile.photos.filter(moderation_status=Photo.Moderation.APPROVED).count()


def core_answers_needed(total_core: int) -> int:
    """Core answers required to go live: the configured minimum, never more than exist."""
    return min(settings.GO_LIVE_MIN_CORE_ANSWERS, total_core)


def missing_for_go_live(profile: Profile) -> list[str]:
    missing = [f for f in REQUIRED_FIELDS if not getattr(profile, f)]
    if not verification_selectors.is_verified_adult(profile.account):
        missing.append("verification")
    if _approved_photos(profile) < settings.GO_LIVE_MIN_PHOTOS:
        missing.append("photos")
    if profile.current_description_id is None:
        missing.append("description")
    answered, total = questionnaire_selectors.core_progress(profile.account_id)
    if total == 0 or answered < core_answers_needed(total):
        missing.append("questionnaire")
    return missing


def complete_later(profile: Profile) -> list[str]:
    """Nudges that improve matches but never block going live (each code appears until it is done)."""
    later = []
    if _approved_photos(profile) < settings.PHOTOS_MAX:
        later.append("more_photos")
    answered, total = questionnaire_selectors.core_progress(profile.account_id)
    if answered < total:
        later.append("more_questions")
    later += [f for f in LATER_FIELDS if not getattr(profile, f)]
    if any(not getattr(profile, f) for f in OPTIONAL_FIELDS):
        later.append("optional_details")
    return later


def completeness(profile: Profile) -> int:
    """0-100. Go-live items 60 (fields 20, photos 15, description 15, the minimum core answers 10); "complete
    later" 40 (remaining core answers 15, extra photos 10, timeline + optional fields 10, optional answers 5)."""
    req_fields = sum(1 for f in REQUIRED_FIELDS if getattr(profile, f))
    points = 20 * req_fields / len(REQUIRED_FIELDS)
    approved = _approved_photos(profile)
    need_photos = max(settings.GO_LIVE_MIN_PHOTOS, 1)
    points += 15 * min(approved, need_photos) / need_photos
    points += 15 if profile.current_description_id else 0
    answered, total = questionnaire_selectors.core_progress(profile.account_id)
    need = core_answers_needed(total)
    if need:
        points += 10 * min(answered, need) / need
    if total > need:
        points += 15 * min(max(answered - need, 0), total - need) / (total - need)
    extra_cap = settings.PHOTOS_MAX - need_photos
    if extra_cap > 0:
        points += 10 * min(max(approved - need_photos, 0), extra_cap) / extra_cap
    later = (*LATER_FIELDS, *OPTIONAL_FIELDS)
    points += 10 * sum(1 for f in later if getattr(profile, f)) / len(later)
    points += 5 if questionnaire_selectors.has_optional_answers(profile.account_id) else 0
    return min(round(points), 100)

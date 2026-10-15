"""Profile photo operations (MC-048). Kept separate from `services` to keep both files readable."""

import uuid
from typing import TYPE_CHECKING

from django.conf import settings
from django.db import transaction

from mc.common.errors import Conflict, LimitReached, NotFound, ValidationFailed
from mc.media import selectors as media_selectors

from .models import Photo, Profile

if TYPE_CHECKING:
    from mc.accounts.models import Account


def _moderation_for(media) -> str:  # type: ignore[no-untyped-def]
    return {
        "approved": Photo.Moderation.APPROVED,
        "review": Photo.Moderation.PENDING,
        "rejected": Photo.Moderation.REJECTED,
    }.get(media.moderation, Photo.Moderation.PENDING)


def add_photo(*, account: "Account", media_id: uuid.UUID) -> Photo:
    from . import services

    profile = services.get_or_create_profile(account=account)
    media = media_selectors.get_media(media_id)
    if media is None or media.owner_id != account.id or media.purpose != "profile_photo":
        raise NotFound()
    if media.status == "rejected":
        raise ValidationFailed("That photo couldn't be accepted.", reason=media.reject_reason)
    if media.status != "ready":
        raise Conflict("That photo is still being processed. Try again in a moment.")
    with transaction.atomic():
        profile = Profile.objects.select_for_update().get(pk=profile.pk)
        existing = list(profile.photos.all())
        if len(existing) >= settings.PHOTOS_MAX:
            raise LimitReached(f"You can add up to {settings.PHOTOS_MAX} photos.")
        if any(p.media_id == media.id for p in existing):
            return next(p for p in existing if p.media_id == media.id)
        photo = Photo.objects.create(
            profile=profile,
            media=media,
            position=max((p.position for p in existing), default=-1) + 1,
            moderation_status=_moderation_for(media),
            face_match=(media.face_count or 0) > 0,
        )
        services.refresh(profile)
    return photo


def delete_photo(*, account: "Account", photo_id: uuid.UUID) -> None:
    from . import services

    with transaction.atomic():
        photo = (
            Photo.objects.select_related("profile")
            .filter(id=photo_id, profile__account=account)
            .first()
        )
        if photo is None:
            raise NotFound()
        profile = Profile.objects.select_for_update().get(pk=photo.profile_id)
        photo.delete()
        remaining = list(profile.photos.order_by("position"))
        _renumber(remaining)
        services.refresh(profile)


def _renumber(photos: list[Photo]) -> None:
    # DEFERRABLE INITIALLY DEFERRED unique constraint lets us rewrite positions in one transaction.
    for i, p in enumerate(photos):
        if p.position != i:
            p.position = i
            p.save(update_fields=["position", "updated_at"])


def reorder_photos(*, account: "Account", ordered_ids: list[uuid.UUID]) -> list[Photo]:
    with transaction.atomic():
        profile = Profile.objects.select_for_update().filter(account=account).first()
        if profile is None:
            raise NotFound()
        photos = {p.id: p for p in profile.photos.all()}
        if len(set(ordered_ids)) != len(ordered_ids) or set(ordered_ids) != set(photos):
            raise ValidationFailed("Send every photo id exactly once.")
        ordered = [photos[i] for i in ordered_ids]
        _renumber(ordered)
        return ordered


def review_photo(*, photo_id: uuid.UUID, approve: bool) -> Photo:
    """Human decision on a photo flagged for review (moderation queue, MC-087)."""
    from . import services

    with transaction.atomic():
        photo = Photo.objects.select_related("profile").select_for_update().get(id=photo_id)
        photo.moderation_status = (
            Photo.Moderation.APPROVED if approve else Photo.Moderation.REJECTED
        )
        photo.save(update_fields=["moderation_status", "updated_at"])
        services.refresh(photo.profile)
    return photo

import uuid

from django.conf import settings

from . import storage
from .models import MediaObject
from .policies import can_view_media


def get_media(media_id: uuid.UUID) -> MediaObject | None:
    return MediaObject.objects.filter(id=media_id).first()


def signed_url(media: MediaObject, viewer) -> str | None:  # type: ignore[no-untyped-def]
    """GET URL valid MEDIA_SIGNED_URL_SECONDS, or None if the viewer may not see it / not ready."""
    if media.status != MediaObject.Status.READY or not media.storage_key:
        return None
    if not can_view_media(viewer, media):
        return None
    return storage.presign_get(key=media.storage_key, ttl=settings.MEDIA_SIGNED_URL_SECONDS)


def owned_ready_media(account_id: uuid.UUID):  # type: ignore[no-untyped-def]
    return MediaObject.objects.filter(
        owner_id=account_id, status=MediaObject.Status.READY
    ).order_by("id")

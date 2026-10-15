import hashlib
import tempfile
import uuid
from pathlib import Path
from typing import TYPE_CHECKING

from django.conf import settings
from django.db import transaction
from django.utils import timezone

from mc.common import ratelimit
from mc.common.errors import Conflict, NotFound, ValidationFailed

from . import processing, storage
from .models import MediaObject
from .providers.moderation import get_moderation_provider
from .providers.scanner import get_scanner

if TYPE_CHECKING:
    from mc.accounts.models import Account

IMAGE_PURPOSES = {MediaObject.Purpose.PROFILE_PHOTO, MediaObject.Purpose.CHAT_IMAGE}
DECLARED_MIMES = {
    "profile_photo": processing.ALLOWED_IMAGE_MIMES,
    "chat_image": processing.ALLOWED_IMAGE_MIMES,
    "voice_note": {"audio/mp4", "audio/aac", "audio/mpeg", "audio/ogg", "audio/webm", "audio/x-m4a", "audio/wav"},
}  # fmt: skip


def _max_bytes(purpose: str) -> int:
    return (
        settings.MEDIA_IMAGE_MAX_BYTES
        if purpose in IMAGE_PURPOSES
        else settings.MEDIA_VOICE_MAX_BYTES
    )


def create_upload(
    *, owner: "Account", purpose: str, mime: str, size: int, sha256: str = ""
) -> tuple[MediaObject, storage.PresignedPost]:
    if purpose not in MediaObject.Purpose.values:
        raise ValidationFailed("Unknown purpose.")
    if mime not in DECLARED_MIMES[purpose]:
        raise ValidationFailed("That file type isn't supported.")
    if not 1 <= size <= _max_bytes(purpose):
        raise ValidationFailed("That file is too large.", max_bytes=_max_bytes(purpose))
    if sha256 and (len(sha256) != 64 or any(c not in "0123456789abcdef" for c in sha256.lower())):
        raise ValidationFailed("sha256 must be 64 hex characters.")
    ratelimit.hit(
        f"media:upload:{owner.id}", limit=settings.MEDIA_UPLOADS_PER_HOUR, window_seconds=3600
    )
    media_id = uuid.uuid4()
    media = MediaObject.objects.create(
        id=media_id,
        owner=owner,
        purpose=purpose,
        declared_mime=mime,
        declared_bytes=size,
        declared_sha256=sha256.lower(),
        upload_key=f"uploads/{media_id}",
    )
    post = storage.presign_post(
        key=media.upload_key, content_type=mime, max_bytes=_max_bytes(purpose)
    )
    return media, post


def complete_upload(*, owner: "Account", media_id: uuid.UUID) -> MediaObject:
    from .tasks import process_media

    with transaction.atomic():
        media = MediaObject.objects.select_for_update().filter(id=media_id, owner=owner).first()
        if media is None:
            raise NotFound()
        if media.status != MediaObject.Status.AWAITING_UPLOAD:
            return media  # idempotent
        if storage.head_size(media.upload_key) is None:
            raise Conflict("The upload hasn't arrived yet.")
        media.status = MediaObject.Status.SCANNING
        media.save(update_fields=["status", "updated_at"])
        transaction.on_commit(lambda: process_media.delay(str(media.id)))
    return media


def _reject(media: MediaObject, reason: str) -> MediaObject:
    media.status, media.reject_reason = MediaObject.Status.REJECTED, reason
    media.processed_at = timezone.now()
    media.save()
    storage.delete(media.upload_key)
    return media


def process_media(*, media_id: uuid.UUID) -> MediaObject | None:
    """Worker body (idempotent): verify → scan → re-encode → moderate → ready/rejected."""
    with transaction.atomic():
        media = MediaObject.objects.select_for_update().filter(id=media_id).first()
        if media is None or media.status != MediaObject.Status.SCANNING:
            return media
        size = storage.head_size(media.upload_key)
        if size is None:
            return _reject(media, "missing_upload")
        if size > _max_bytes(media.purpose) or size > media.declared_bytes:
            return _reject(media, "too_large")
        with storage.download_to_tempfile(media.upload_key) as raw:
            path = Path(raw.name)
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            if media.declared_sha256 and digest != media.declared_sha256:
                return _reject(media, "checksum_mismatch")
            media.sha256 = digest
            if not get_scanner().is_clean(path):
                return _reject(media, "malware")
            try:
                if media.purpose in IMAGE_PURPOSES:
                    real = processing.sniff_mime(path)
                    if real != media.declared_mime:
                        raise processing.Rejected("type_mismatch")
                    out = processing.process_image(path)
                    result = get_moderation_provider().analyse(path)
                    data, mime, ext = out.data, "image/webp", "webp"
                    media.width, media.height = out.width, out.height
                    media.face_count = result.face_count
                    media.moderation_labels = result.labels
                    if result.nudity or result.violence:
                        media.moderation = MediaObject.Moderation.REJECTED
                        raise processing.Rejected("moderation_rejected")
                    media.moderation = (
                        MediaObject.Moderation.REVIEW
                        if result.minor_suspected
                        else MediaObject.Moderation.APPROVED
                    )
                else:
                    with tempfile.NamedTemporaryFile(suffix=".m4a") as out_file:
                        audio = processing.process_audio(path, Path(out_file.name))
                    data, mime, ext = audio.data, "audio/mp4", "m4a"
                    media.duration_ms = audio.duration_ms
            except processing.Rejected as exc:
                return _reject(media, exc.reason)
        media.storage_key = f"media/{media.id}.{ext}"
        storage.put_bytes(media.storage_key, data, mime)
        storage.delete(media.upload_key)
        media.mime, media.bytes = mime, len(data)
        media.status, media.processed_at = MediaObject.Status.READY, timezone.now()
        media.save()
    return media


def delete_all_for(*, account_id: uuid.UUID) -> int:
    """Erasure: remove every stored object (raw and processed) and the rows, for one owner."""
    n = 0
    for media in MediaObject.objects.filter(owner_id=account_id):
        for key in {media.upload_key, media.storage_key}:
            if key:
                storage.delete(key)
        n += 1
    MediaObject.objects.filter(owner_id=account_id).delete()
    return n


def export_files_for(*, account_id: uuid.UUID) -> list[tuple[str, bytes]]:
    """`[(name, bytes)]` of the member's own processed uploads for their data export (missing files skipped)."""
    out = []
    for m in selectors_owned(account_id):
        blob = storage.read_bytes(m.storage_key)
        if blob is not None:
            out.append((f"media/{m.id}.{m.storage_key.rsplit('.', 1)[-1]}", blob))
    return out


def selectors_owned(account_id: uuid.UUID):  # type: ignore[no-untyped-def]
    from . import selectors

    return selectors.owned_ready_media(account_id)


def delete_export_object(*, key: str) -> None:
    storage.delete_in(bucket=settings.EXPORTS_BUCKET, key=key)

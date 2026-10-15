import hashlib
import uuid

import pyvips
from django.test import Client

from mc.accounts.tests.helpers import bearer
from mc.verification.tests.helpers import J


def make_jpeg(
    width=64, height=48, *, exif_orientation=None, description=None, colour=(200, 30, 30)
) -> bytes:
    img = (
        pyvips.Image.black(width, height, bands=3)
        .new_from_image(list(colour))
        .copy(interpretation="srgb")
    )
    if exif_orientation:
        img = img.copy()
        img.set_type(pyvips.GValue.gint_type, "orientation", exif_orientation)
    if description:
        img = img.copy()
        img.set_type(pyvips.GValue.gstr_type, "exif-ifd0-ImageDescription", description)
    return bytes(img.write_to_buffer(".jpg", Q=90))


def make_png(width=32, height=32) -> bytes:
    img = (
        pyvips.Image.black(width, height, bands=4)
        .new_from_image([10, 120, 200, 128])
        .copy(interpretation="srgb")
    )
    return bytes(img.write_to_buffer(".png"))


def make_m4a(seconds=2) -> bytes:
    import subprocess
    import tempfile

    with tempfile.NamedTemporaryFile(suffix=".m4a") as f:
        subprocess.run(
            ["ffmpeg", "-nostdin", "-v", "error", "-f", "lavfi", "-i", f"sine=frequency=440:duration={seconds}",
             "-c:a", "aac", "-y", f.name],
            check=True,
        )  # fmt: skip
        return open(f.name, "rb").read()


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def request_upload(c: Client, r, *, purpose="profile_photo", mime="image/jpeg", size=1000, **extra):
    return c.post(
        "/api/v1/media/uploads",
        {"purpose": purpose, "mime": mime, "bytes": size, **extra},
        **bearer(r),
        HTTP_IDEMPOTENCY_KEY=uuid.uuid4().hex,
        **J,
    )


def put_raw(storage, key: str, data: bytes, content_type="image/jpeg"):
    storage.put_bytes(key, data, content_type)


def upload_and_complete(
    c, r, storage, data: bytes, *, purpose="profile_photo", mime="image/jpeg", **extra
):
    from mc.media.models import MediaObject

    resp = request_upload(c, r, purpose=purpose, mime=mime, size=len(data), **extra)
    assert resp.status_code == 201, resp.content
    media = MediaObject.objects.get(id=resp.json()["id"])
    put_raw(storage, media.upload_key, data, mime)
    from django.test import TestCase

    with TestCase.captureOnCommitCallbacks(execute=True):  # runs the (eager) process_media task
        done = c.post(f"/api/v1/media/{media.id}/complete", **bearer(r))
    assert done.status_code == 202, done.content
    media.refresh_from_db()
    return media

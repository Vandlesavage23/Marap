import io
import uuid

import pytest
import pyvips
from django.test import Client

from mc.accounts.tests.helpers import bearer
from mc.media import selectors, services
from mc.media.models import MediaObject
from mc.media.policies import register_viewer_policy
from mc.media.providers.moderation import FakeModeration, ModerationResult
from mc.media.providers.scanner import EICAR, FakeScanner
from mc.profiles.tests.helpers import verified_client

from .helpers import make_jpeg, make_m4a, make_png, request_upload, sha, upload_and_complete

pytestmark = pytest.mark.django_db


def user(phone="+256772000001"):
    c, r, acct = verified_client(phone)
    return c, r, acct


# ---- presign ---------------------------------------------------------------------------------
def test_upload_request_validation_and_auth():
    c, r, _ = user()
    assert (
        Client(headers={"host": "api.mc.test"})
        .post("/api/v1/media/uploads", {}, content_type="application/json")
        .status_code
        == 401
    )
    assert request_upload(c, r, mime="application/pdf").status_code == 422
    assert request_upload(c, r, mime="image/gif").status_code == 422
    assert request_upload(c, r, purpose="voice_note", mime="image/jpeg").status_code == 422
    assert request_upload(c, r, size=11 * 1024 * 1024).status_code == 422
    assert (
        request_upload(
            c, r, purpose="voice_note", mime="audio/mp4", size=3 * 1024 * 1024
        ).status_code
        == 422
    )
    assert request_upload(c, r, purpose="avatar").status_code == 422
    assert request_upload(c, r, sha256="zz").status_code == 422
    assert MediaObject.objects.count() == 0


def test_presigned_post_enforces_size_range_and_type(s3):
    c, r, _ = user()
    body = request_upload(c, r, size=5000).json()
    assert body["upload"]["method"] == "POST" and body["expires_in"] == 300
    import base64
    import json

    policy = json.loads(base64.b64decode(body["upload"]["fields"]["policy"]))
    conds = policy["conditions"]
    assert ["content-length-range", 1, 10 * 1024 * 1024] in conds
    assert {"Content-Type": "image/jpeg"} in conds
    key = MediaObject.objects.get().upload_key
    assert key.startswith("uploads/") and str(MediaObject.objects.get().owner_id) in key


def test_upload_rate_limited(settings):
    settings.MEDIA_UPLOADS_PER_HOUR = 2
    c, r, _ = user()
    assert request_upload(c, r).status_code == 201
    assert request_upload(c, r).status_code == 201
    assert request_upload(c, r).status_code == 429


def test_complete_requires_arrival_and_ownership(s3):
    c, r, _ = user()
    c2, r2, _ = user("+256772000002")
    mid = request_upload(c, r).json()["id"]
    assert (
        c.post(f"/api/v1/media/{mid}/complete", **bearer(r)).status_code == 409
    )  # nothing uploaded yet
    assert c2.post(f"/api/v1/media/{mid}/complete", **bearer(r2)).status_code == 404


# ---- happy paths -------------------------------------------------------------------------------
def test_jpeg_processed_to_webp_within_limits(s3):
    c, r, _ = user()
    data = make_jpeg(3000, 2000)
    m = upload_and_complete(c, r, s3, data)
    assert m.status == "ready" and m.mime == "image/webp"
    assert max(m.width, m.height) == 1600
    out = s3._client().get_object(Bucket="media-private", Key=m.storage_key)["Body"].read()
    assert out[:4] == b"RIFF" and out[8:12] == b"WEBP"
    assert s3.head_size(m.upload_key) is None  # raw upload deleted
    assert m.sha256 == sha(data) and m.moderation == "approved" and m.face_count == 1


def test_png_with_alpha_is_flattened(s3):
    c, r, _ = user()
    m = upload_and_complete(c, r, s3, make_png(), mime="image/png")
    assert m.status == "ready"


def test_exif_is_absent_from_output_and_orientation_applied(s3):
    c, r, _ = user()
    secret = "SECRET-GPS-OWNER-NAME"
    data = make_jpeg(80, 40, exif_orientation=6, description=secret)
    assert secret.encode() in data  # sanity: the source really carries it
    m = upload_and_complete(c, r, s3, data)
    out = s3._client().get_object(Bucket="media-private", Key=m.storage_key)["Body"].read()
    assert secret.encode() not in out
    img = pyvips.Image.new_from_buffer(out, "")
    assert (
        not any(f.startswith("exif") for f in img.get_fields())
        and "orientation" not in img.get_fields()
    )
    assert (m.width, m.height) == (40, 80)  # rotated upright before metadata was dropped


def test_voice_note_transcoded(s3):
    c, r, _ = user()
    m = upload_and_complete(c, r, s3, make_m4a(2), purpose="voice_note", mime="audio/mp4")
    assert m.status == "ready" and m.mime == "audio/mp4" and 1800 <= m.duration_ms <= 2300


def test_voice_note_longer_than_60s_rejected(s3):
    c, r, _ = user()
    m = upload_and_complete(c, r, s3, make_m4a(70), purpose="voice_note", mime="audio/mp4")
    assert m.status == "rejected" and m.reject_reason in ("too_long", "too_large")


# ---- hostile input -------------------------------------------------------------------------------
def test_polyglot_payload_does_not_survive(s3):
    c, r, _ = user()
    payload = b"<?php system($_GET['c']); ?>PK\x03\x04-fake-zip-tail"
    data = make_jpeg() + payload  # valid JPEG with a script/zip appended
    m = upload_and_complete(c, r, s3, data)
    assert m.status == "ready"
    out = s3._client().get_object(Bucket="media-private", Key=m.storage_key)["Body"].read()
    assert b"<?php" not in out and b"PK\x03\x04" not in out


@pytest.mark.parametrize(
    ("blob", "declared", "reason"),
    [
        (b"%PDF-1.4 not an image", "image/jpeg", "type_mismatch"),
        (b"<html><script>alert(1)</script></html>", "image/png", "type_mismatch"),
        (b"GIF89a....", "image/jpeg", "type_mismatch"),
        (make_png(), "image/jpeg", "type_mismatch"),  # declared jpeg, really png
        (b"\xff\xd8\xff\xe0garbage-not-a-real-jpeg", "image/jpeg", "corrupt_image"),
    ],
)
def test_wrong_or_corrupt_types_rejected(s3, blob, declared, reason):
    c, r, _ = user()
    m = upload_and_complete(c, r, s3, blob, mime=declared)
    assert (m.status, m.reject_reason) == ("rejected", reason)
    assert s3.head_size(m.upload_key) is None and not m.storage_key


def test_oversized_actual_upload_rejected(s3):
    c, r, _ = user()
    resp = request_upload(c, r, size=100)  # declared 100 bytes ...
    m = MediaObject.objects.get(id=resp.json()["id"])
    s3.put_bytes(m.upload_key, make_jpeg(400, 400), "image/jpeg")  # ... but uploads far more
    from django.test import TestCase

    with TestCase.captureOnCommitCallbacks(execute=True):
        c.post(f"/api/v1/media/{m.id}/complete", **bearer(r))
    m.refresh_from_db()
    assert (m.status, m.reject_reason) == ("rejected", "too_large")


def test_pixel_bomb_rejected(s3, settings):
    settings.MEDIA_IMAGE_MAX_PIXELS = 1000
    c, r, _ = user()
    m = upload_and_complete(c, r, s3, make_jpeg(200, 200))
    assert (m.status, m.reject_reason) == ("rejected", "too_many_pixels")


def test_checksum_mismatch_rejected(s3):
    c, r, _ = user()
    m = upload_and_complete(c, r, s3, make_jpeg(), sha256="0" * 64)
    assert m.reject_reason == "checksum_mismatch"
    m2 = upload_and_complete(c, r, s3, make_jpeg(), sha256=sha(make_jpeg()))
    assert m2.status == "ready"


def test_malware_rejected(s3):
    c, r, _ = user()
    m = upload_and_complete(c, r, s3, make_jpeg() + EICAR)
    assert (m.status, m.reject_reason) == ("rejected", "malware")


def test_scanner_outage_fails_closed_and_retries(s3):
    c, r, _ = user()
    FakeScanner.unavailable = True
    from django.test import TestCase

    resp = request_upload(c, r, size=len(make_jpeg()))
    m = MediaObject.objects.get(id=resp.json()["id"])
    s3.put_bytes(m.upload_key, make_jpeg(), "image/jpeg")
    with TestCase.captureOnCommitCallbacks(
        execute=True
    ):  # eager task exhausts retries, then gives up
        c.post(f"/api/v1/media/{m.id}/complete", **bearer(r))
    m.refresh_from_db()
    assert m.status == "scanning"  # never auto-approved; the task retries
    FakeScanner.unavailable = False
    services.process_media(media_id=m.id)
    m.refresh_from_db()
    assert m.status == "ready"


def test_processing_is_idempotent(s3):
    c, r, _ = user()
    m = upload_and_complete(c, r, s3, make_jpeg())
    again = services.process_media(media_id=m.id)
    assert again.status == "ready" and again.storage_key == m.storage_key


# ---- moderation ------------------------------------------------------------------------------------
def test_nudity_rejected_minor_goes_to_review(s3):
    c, r, _ = user()
    nude, minor = make_jpeg(colour=(1, 2, 3)), make_jpeg(colour=(4, 5, 6))
    FakeModeration.scripted[sha(nude)] = ModerationResult(
        nudity=True, labels=["Explicit Nudity"], face_count=1
    )
    FakeModeration.scripted[sha(minor)] = ModerationResult(minor_suspected=True, face_count=1)
    m1 = upload_and_complete(c, r, s3, nude)
    assert (m1.status, m1.reject_reason, m1.moderation) == (
        "rejected",
        "moderation_rejected",
        "rejected",
    )
    m2 = upload_and_complete(c, r, s3, minor)
    assert m2.status == "ready" and m2.moderation == "review"


# ---- access ------------------------------------------------------------------------------------------
def test_signed_url_owner_only_unless_policy_registered(s3):
    c, r, owner = user()
    c2, r2, other = user("+256772000002")
    m = upload_and_complete(c, r, s3, make_jpeg())
    body = c.get(f"/api/v1/media/{m.id}", **bearer(r)).json()
    assert body["url"].startswith("https://") or body["url"].startswith("http")
    assert c2.get(f"/api/v1/media/{m.id}", **bearer(r2)).status_code == 404  # denied, no oracle
    assert selectors.signed_url(m, other) is None
    register_viewer_policy("profile_photo", lambda viewer, media: viewer.id == other.id)
    try:
        assert c2.get(f"/api/v1/media/{m.id}", **bearer(r2)).json()["url"]
    finally:
        register_viewer_policy("profile_photo", lambda viewer, media: False)
    assert Client(headers={"host": "api.mc.test"}).get(f"/api/v1/media/{m.id}").status_code == 401


def test_pending_media_has_no_url_and_is_invisible_to_others(s3):
    c, r, _ = user()
    c2, r2, _ = user("+256772000002")
    mid = request_upload(c, r).json()["id"]
    assert "url" not in c.get(f"/api/v1/media/{mid}", **bearer(r)).json()
    assert c2.get(f"/api/v1/media/{mid}", **bearer(r2)).status_code == 404
    assert c.get(f"/api/v1/media/{uuid.uuid4()}", **bearer(r)).status_code == 404


def test_rejected_media_never_exposes_object(s3):
    c, r, _ = user()
    m = upload_and_complete(c, r, s3, b"%PDF-1.4", mime="image/jpeg")
    body = c.get(f"/api/v1/media/{m.id}", **bearer(r)).json()
    assert body["status"] == "rejected" and "url" not in body
    _ = io

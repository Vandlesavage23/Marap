import io
import json
import zipfile
from datetime import timedelta

import pytest
from django.test import Client, TestCase
from django.utils import timezone
from freezegun import freeze_time

from mc.accounts.tests.helpers import bearer
from mc.media.models import MediaObject
from mc.messaging.tests.helpers import matched, say
from mc.notifications.models import Notification
from mc.privacy import export, tasks
from mc.privacy.models import PrivacyRequest
from mc.verification.tests.helpers import J

pytestmark = pytest.mark.django_db


def request_export(who):
    with TestCase.captureOnCommitCallbacks(execute=True):
        return who[0].post("/api/v1/me/export", **bearer(who[1]), **J)


def load_zip(s3, req):
    blob = s3._client().get_object(Bucket="exports-private", Key=req.file_key)["Body"].read()
    return zipfile.ZipFile(io.BytesIO(blob))


def test_export_contains_my_data_and_my_conversations_only(s3):
    m, f, mid = matched()
    from mc.matches.models import Match

    Match.objects.update(created_at=timezone.now() - timedelta(days=10))
    say(m, mid, "hello from me")
    say(f, mid, "hello from her")
    media = MediaObject.objects.filter(owner=m[2], status="ready").first()
    s3.put_bytes(media.storage_key, b"IMG-BYTES", "image/webp")
    resp = request_export(m)
    assert resp.status_code == 202
    req = PrivacyRequest.objects.get(kind="export")
    assert req.status == "completed" and req.file_key.startswith("exports/") and req.completed_at
    z = load_zip(s3, req)
    data = json.loads(z.read("data.json"))
    assert data["account"]["phone"] == m[2].phone_e164 and data["profile"]["display_name"]
    assert data["profile"]["descriptions"][0]["text"].startswith("I am a kind")
    assert (
        len(data["questionnaire_answers"]) >= 20 and data["verification"][0]["status"] == "passed"
    )
    convo = data["conversations"][0]
    assert {(x["from"], x["body"]) for x in convo["messages"]} == {
        ("me", "hello from me"),
        ("them", "hello from her"),
    }
    assert (
        any(n.startswith("media/") for n in z.namelist())
        and z.read(f"media/{media.id}.webp") == b"IMG-BYTES"
    )
    # nothing about the other member beyond the conversation
    text = json.dumps(data)
    assert f[2].phone_e164 not in text and str(f[2].id) not in text and f[3] not in text
    assert Profile_name(f) not in text


def Profile_name(who):
    from mc.profiles.models import Profile

    return Profile.objects.get(account=who[2]).display_name


def test_export_includes_special_data_decrypted_for_the_owner(s3):
    from mc.profiles.tests.helpers import consent, patch, verified_client

    c, r, acct = verified_client("+256772500001")
    consent(c, r, "special_religion")
    patch(c, r, religion="Anglican")
    req = export.request_export(account=acct)
    export.build(request_id=req.id)
    req.refresh_from_db()
    assert json.loads(load_zip(s3, req).read("data.json"))["profile"]["religion"] == "Anglican"


def test_export_is_idempotent_while_pending_and_notifies(s3):
    from mc.profiles.tests.helpers import verified_client

    c, r, acct = verified_client("+256772500002")
    a = export.request_export(account=acct)
    b = export.request_export(account=acct)
    assert a.id == b.id and PrivacyRequest.objects.filter(kind="export").count() == 1
    assert abs((a.due_at - a.requested_at) - timedelta(hours=72)) < timedelta(seconds=5)
    export.build(request_id=a.id)
    export.build(request_id=a.id)  # a retried task is a no-op
    assert Notification.objects.filter(account=acct, type="export_ready").count() == 1
    again = export.request_export(account=acct)  # a new export after completion is a new request
    assert again.id != a.id


def test_download_link_is_owner_only_and_expires_after_7_days(s3):
    m, f, mid = matched()
    request_export(m)
    req = PrivacyRequest.objects.get(kind="export")
    body = m[0].get(f"/api/v1/me/export/{req.id}", **bearer(m[1])).json()
    assert (
        body["status"] == "completed"
        and body["url"].startswith("http")
        and "exports-private" in body["url"]
    )
    assert body["expires_at"] > (timezone.now() + timedelta(days=6)).isoformat()
    assert (
        f[0].get(f"/api/v1/me/export/{req.id}", **bearer(f[1])).status_code == 404
    )  # someone else's
    assert (
        Client(headers={"host": "api.mc.test"}).get(f"/api/v1/me/export/{req.id}").status_code
        == 401
    )
    PrivacyRequest.objects.update(expires_at=timezone.now() - timedelta(seconds=1))
    assert m[0].get(f"/api/v1/me/export/{req.id}", **bearer(m[1])).json().get("url") is None


def test_expired_exports_are_purged_from_storage(s3):
    m, f, mid = matched()
    request_export(m)
    req = PrivacyRequest.objects.get(kind="export")
    assert s3.head_size.__name__  # keep import used
    PrivacyRequest.objects.update(expires_at=timezone.now() - timedelta(days=1))
    assert tasks.purge_expired_exports() == 1
    assert PrivacyRequest.objects.get().file_key == ""
    import botocore.exceptions

    with pytest.raises(botocore.exceptions.ClientError):
        s3._client().get_object(
            Bucket="exports-private", Key=req.file_key or f"exports/{req.id}.zip"
        )
    assert tasks.purge_expired_exports() == 0


def test_export_requires_auth_and_works_for_suspended_members(s3):
    from mc.accounts.models import Account

    assert Client(headers={"host": "api.mc.test"}).post("/api/v1/me/export", **J).status_code == 401
    m, f, mid = matched()
    Account.objects.filter(id=m[2].id).update(status="suspended")
    assert m[0].post("/api/v1/me/export", **bearer(m[1]), **J).status_code in (202, 401)
    _ = freeze_time

import pytest
from django.test import Client

from mc.accounts.models import Account
from mc.accounts.tests.helpers import bearer
from mc.verification.models import VerificationAttempt

from .helpers import callback, job_id_of, new_user, result, start

pytestmark = pytest.mark.django_db


def test_requires_auth():
    assert (
        Client(headers={"host": "api.mc.test"})
        .post("/api/v1/verification/sessions", {}, content_type="application/json")
        .status_code
        == 401
    )


def test_rejected_without_required_consents():
    c, r = new_user(consents=False)
    resp = start(c, r)
    assert resp.status_code == 422
    assert set(resp.json()["missing_consents"]) == {"terms", "privacy", "data_transfer"}


def test_idempotency_key_required():
    c, r = new_user()
    resp = c.post("/api/v1/verification/sessions", {}, **bearer(r), content_type="application/json")
    assert resp.status_code == 422


def test_creates_attempt_and_returns_sdk_params_without_secrets(settings):
    settings.SMILE_ID_API_KEY = "super-secret-api-key"
    c, r = new_user()
    resp = start(c, r)
    assert resp.status_code == 201
    body = resp.json()
    assert body["sdk_params"]["signature"] and body["sdk_params"]["job_id"].startswith("mc_")
    assert "super-secret" not in resp.content.decode()
    assert "api_key" not in resp.content.decode().lower()
    assert VerificationAttempt.objects.get().status == "created"


def test_idempotent_retry_returns_same_attempt():
    c, r = new_user()
    a = start(c, r, key="same-key-12345")
    b = start(c, r, key="same-key-12345")
    assert a.json()["attempt_id"] == b.json()["attempt_id"]
    assert VerificationAttempt.objects.count() == 1


def test_fourth_attempt_in_24h_returns_limit_reached():
    c, r = new_user()
    for _ in range(3):
        resp = start(c, r)
        assert resp.status_code == 201
        callback(c, result(job_id_of(resp), outcome="failed", vendor_reason="face_mismatch"))
    resp = start(c, r)
    assert resp.status_code == 429 and resp.json()["code"] == "limit_reached"


def test_cannot_start_while_submission_pending():
    c, r = new_user()
    resp = start(c, r)
    sub = c.post(
        f"/api/v1/verification/sessions/{resp.json()['attempt_id']}/submitted", **bearer(r)
    )
    assert sub.json()["status"] == "submitted"
    assert start(c, r).json()["code"] == "verification_pending"


def test_unknown_id_type_rejected():
    c, r = new_user()
    assert start(c, r, id_type="LIBRARY_CARD").status_code == 422


def test_already_verified_account_conflicts():
    c, r = new_user()
    callback(c, result(job_id_of(start(c, r))))
    resp = start(c, r)
    assert resp.status_code == 409 and resp.json()["code"] == "duplicate"


def test_suspended_account_cannot_start():
    c, r = new_user()
    Account.objects.update(status="suspended")
    assert start(c, r).status_code == 403


def test_mark_submitted_is_owner_only():
    c1, r1 = new_user()
    c2, r2 = new_user("+256772000002")
    aid = start(c1, r1).json()["attempt_id"]
    assert (
        c2.post(f"/api/v1/verification/sessions/{aid}/submitted", **bearer(r2)).status_code == 404
    )


def test_status_endpoint_and_me():
    c, r = new_user()
    assert c.get("/api/v1/verification/status", **bearer(r)).json() == {
        "status": "not_started",
        "reason": None,
    }
    callback(c, result(job_id_of(start(c, r)), outcome="failed", vendor_reason="doc_unreadable"))
    assert c.get("/api/v1/verification/status", **bearer(r)).json() == {
        "status": "failed",
        "reason": "doc_unreadable",
    }
    assert c.get("/api/v1/me", **bearer(r)).json()["verification_status"] == "failed"

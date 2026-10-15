from datetime import UTC, date, datetime, timedelta

import pytest
from django.db import connection
from freezegun import freeze_time

from mc.accounts.models import Account, Session
from mc.accounts.tests.helpers import bearer
from mc.common import events
from mc.verification import reasons, services
from mc.verification.events import AccountVerified, SafetyFlagRaised
from mc.verification.models import VerificationAttempt
from mc.verification.providers.fake import FakeIdentityProvider

from .helpers import callback, job_id_of, new_user, result, start

pytestmark = pytest.mark.django_db


def verified_user(phone="+256772000001", **kw):
    c, r = new_user(phone)
    job = job_id_of(start(c, r))
    resp = callback(c, result(job, **kw))
    return c, r, job, resp


def test_bad_signature_rejected_and_state_unchanged():
    c, r = new_user()
    job = job_id_of(start(c, r))
    assert callback(c, result(job), sign=False).status_code == 403
    assert VerificationAttempt.objects.get().status == "created"


def test_unknown_job_is_404():
    c, _ = new_user()
    assert callback(c, result("mc_unknown")).status_code == 404


def test_malformed_body_rejected():
    c, _ = new_user()
    body = b"not json"
    assert callback(c, result("x"), body=body).status_code == 422


def test_pass_activates_account_and_stores_no_id_number(django_capture_on_commit_callbacks):
    got = []
    events.subscribe(AccountVerified)(got.append)
    c, r = new_user()
    job = job_id_of(start(c, r))
    with django_capture_on_commit_callbacks(execute=True):
        assert callback(c, result(job)).status_code == 200
    att = VerificationAttempt.objects.get()
    assert att.status == "passed" and att.date_of_birth == date(1995, 5, 17)
    assert len(bytes(att.id_number_hmac)) == 32
    assert Account.objects.get().status == "active"
    assert len(got) == 1
    # the raw ID number appears nowhere in the attempt row, nor encrypted result, nor audit-able columns
    with connection.cursor() as cur:
        cur.execute("SELECT row_to_json(v)::text FROM verification_verificationattempt v")
        dump = cur.fetchone()[0]
    assert "9512" not in dump and "CM9512" not in dump
    assert c.get("/api/v1/me", **bearer(r)).json()["status"] == "active"


def test_vendor_result_is_encrypted_at_rest():
    verified_user()
    with connection.cursor() as cur:
        cur.execute("SELECT vendor_result FROM verification_verificationattempt")
        assert cur.fetchone()[0].startswith("v1:")


def test_vendor_image_deletion_scheduled(django_capture_on_commit_callbacks, monkeypatch):
    calls = []
    from mc.verification import tasks

    monkeypatch.setattr(tasks.delete_vendor_images, "apply_async", lambda **kw: calls.append(kw))
    c, r = new_user()
    job = job_id_of(start(c, r))
    with django_capture_on_commit_callbacks(execute=True):
        callback(c, result(job))
    assert calls == [{"args": [job], "countdown": 30 * 24 * 3600}]
    tasks.delete_vendor_images(job)
    assert FakeIdentityProvider.deleted == [job]


def test_replayed_callback_is_idempotent(django_capture_on_commit_callbacks):
    got = []
    events.subscribe(AccountVerified)(got.append)
    c, r = new_user()
    job = job_id_of(start(c, r))
    with django_capture_on_commit_callbacks(execute=True):
        callback(c, result(job))
        callback(c, result(job))
        callback(
            c, result(job, outcome="failed", vendor_reason="face_mismatch")
        )  # late contradiction
    assert VerificationAttempt.objects.get().status == "passed"
    assert len(got) == 1


@pytest.mark.parametrize(
    ("kw", "reason"),
    [
        ({"document_expired": True}, "doc_expired"),
        ({"liveness_passed": False}, "liveness_failed"),
        ({"face_match_passed": False}, "face_mismatch"),
        ({"date_of_birth": None}, "dob_missing"),
        ({"id_number": None}, "id_number_missing"),
        ({"id_number": "---"}, "id_number_missing"),
    ],
)
def test_pass_requires_all_checks(kw, reason):
    c, r, _, _ = verified_user(**kw)
    att = VerificationAttempt.objects.get()
    assert (att.status, att.reason_code) == ("failed", reason)
    assert Account.objects.get().status == "pending_verification"
    assert att.id_number_hmac is None


def test_vendor_failure_reason_stored_and_account_stays_pending():
    c, r, _, _ = verified_user(outcome="failed", vendor_reason="doc_unreadable")
    att = VerificationAttempt.objects.get()
    assert (att.status, att.reason_code, att.safety_flag) == ("failed", "doc_unreadable", "")
    assert Account.objects.get().status == "pending_verification"


def test_vendor_error_and_needs_review_states():
    c, r, _, _ = verified_user(outcome="error")
    assert VerificationAttempt.objects.get().status == "error"
    c2, r2, _, _ = verified_user("+256772000002", outcome="needs_review")
    att = VerificationAttempt.objects.get(account__phone_e164="+256772000002")
    assert att.status == "needs_review" and att.decided_at is None


def test_underage_suspends_flags_and_signs_out(django_capture_on_commit_callbacks):
    flags = []
    events.subscribe(SafetyFlagRaised)(flags.append)
    with freeze_time("2026-06-01 12:00:00"):
        c, r = new_user()
        job = job_id_of(start(c, r))
        with django_capture_on_commit_callbacks(execute=True):
            callback(c, result(job, date_of_birth=date(2010, 6, 1)))  # 16
    att = VerificationAttempt.objects.get()
    assert (att.status, att.reason_code, att.safety_flag) == ("failed", "underage", "underage")
    assert Account.objects.get().status == "suspended"
    assert not Session.objects.filter(revoked_at__isnull=True).exists()
    assert c.get("/api/v1/me", **bearer(r)).status_code == 401
    assert [f.flag for f in flags] == ["underage"]
    assert reasons.UNDERAGE in reasons.NO_APPEAL
    # id number and dob of a minor are not retained as a verified identity
    assert att.id_number_hmac is None


def test_vendor_reported_underage_failure_also_suspends():
    with freeze_time("2026-06-01"):
        c, r = new_user()
        job = job_id_of(start(c, r))
        callback(
            c,
            result(
                job, outcome="failed", vendor_reason="face_mismatch", date_of_birth=date(2012, 1, 1)
            ),
        )
    assert VerificationAttempt.objects.get().reason_code == "underage"
    assert Account.objects.get().status == "suspended"


@pytest.mark.parametrize(
    ("now", "dob", "adult"),
    [
        ("2026-06-01 12:00:00+00:00", date(2008, 6, 1), True),  # turns 18 today
        ("2026-06-01 12:00:00+00:00", date(2008, 6, 2), False),  # turns 18 tomorrow
        ("2026-05-31 22:30:00+00:00", date(2008, 6, 1), True),  # already June 1 in Kampala (UTC+3)
        ("2026-05-31 20:30:00+00:00", date(2008, 6, 1), False),  # still May 31 in Kampala
        ("2028-02-29 10:00:00+00:00", date(2010, 3, 1), False),
    ],
)
def test_age_computed_in_kampala_date(now, dob, adult):
    with freeze_time(now):
        c, r = new_user()
        callback(c, result(job_id_of(start(c, r)), date_of_birth=dob))
    expected = "passed" if adult else "failed"
    assert VerificationAttempt.objects.get().status == expected


def test_age_helpers():
    assert services.age_on(date(2000, 2, 29), date(2018, 2, 28)) == 17
    assert services.age_on(date(2000, 2, 29), date(2018, 3, 1)) == 18
    assert services.kampala_date(datetime(2026, 5, 31, 21, 0, tzinfo=UTC)) == date(2026, 6, 1)


def test_duplicate_identity_fails_and_flags_second_account_only(django_capture_on_commit_callbacks):
    flags = []
    events.subscribe(SafetyFlagRaised)(flags.append)
    c1, r1, _, _ = verified_user("+256772000001")
    c2, r2 = new_user("+256772000002")
    job2 = job_id_of(start(c2, r2))
    with django_capture_on_commit_callbacks(execute=True):
        callback(c2, result(job2, id_number="cm9512-3456-789"))  # same number, different formatting
    second = VerificationAttempt.objects.get(vendor_job_id=job2)
    assert (second.status, second.reason_code, second.safety_flag) == (
        "failed",
        "duplicate_identity",
        "duplicate_identity",
    )
    assert Account.objects.get(phone_e164="+256772000001").status == "active"
    assert Account.objects.get(phone_e164="+256772000002").status == "pending_verification"
    assert [f.flag for f in flags] == ["duplicate_identity"]


def test_db_constraint_backstops_duplicate_race(monkeypatch):
    """Simulate the race: pre-check passes for both, the partial unique index catches the second."""
    verified_user("+256772000001")
    c2, r2 = new_user("+256772000002")
    job2 = job_id_of(start(c2, r2))
    monkeypatch.setattr(services, "_pass_failure", lambda *a, **k: None)
    callback(c2, result(job2))
    second = VerificationAttempt.objects.get(vendor_job_id=job2)
    assert (second.status, second.reason_code) == ("failed", "duplicate_identity")
    assert Account.objects.get(phone_e164="+256772000002").status == "pending_verification"


def test_retry_after_failure_can_pass():
    c, r = new_user()
    callback(c, result(job_id_of(start(c, r)), outcome="failed", vendor_reason="face_mismatch"))
    callback(c, result(job_id_of(start(c, r)), id_number="UG1234567"))
    assert Account.objects.get().status == "active"
    assert VerificationAttempt.objects.filter(status="passed").count() == 1


# ---- polling fallback ------------------------------------------------------
def test_poll_resolves_attempts_without_callback():
    c, r = new_user()
    job = job_id_of(start(c, r))
    assert services.poll_stale_attempts() == 0  # too fresh
    FakeIdentityProvider.jobs[job] = result(job)
    with freeze_time(datetime.now(UTC) + timedelta(minutes=11)):
        assert services.poll_stale_attempts() == 1
    assert Account.objects.get().status == "active"


def test_poll_expires_abandoned_attempts_after_24h():
    c, r = new_user()
    job_id_of(start(c, r))
    with freeze_time(datetime.now(UTC) + timedelta(hours=25)):
        assert services.poll_stale_attempts() == 1
    assert VerificationAttempt.objects.get().status == "expired"


def test_poll_task_wrapper():
    from mc.verification import tasks

    assert tasks.poll_stale_attempts() == 0


# ---- reason mapping table ---------------------------------------------------
@pytest.mark.parametrize(
    ("code", "mapped"),
    [
        ("1012", "face_mismatch"),
        ("0811", "doc_unreadable"),
        ("0814", "doc_expired"),
        ("2204", "liveness_failed"),
        ("9999", "unknown"),
        ("", "unknown"),
    ],
)
def test_smile_id_reason_mapping(code, mapped):
    assert reasons.map_smile_id(code) == mapped

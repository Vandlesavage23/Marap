"""Mandatory scenario tests from the planning package (Bible §13.2)."""

from datetime import date

import pytest
from freezegun import freeze_time

from mc.accounts.models import Account
from mc.accounts.tests.helpers import bearer
from mc.verification.models import VerificationAttempt
from mc.verification.tests.helpers import callback, job_id_of, new_user, result, start

pytestmark = pytest.mark.django_db


@freeze_time("2026-06-01 09:00:00")
def test_scenario_01_under_18_registration_blocked():
    c, r = new_user()
    job = job_id_of(start(c, r))
    callback(c, result(job, date_of_birth=date(2009, 8, 1)))
    assert Account.objects.get().status == "suspended"
    assert VerificationAttempt.objects.get().reason_code == "underage"
    assert c.get("/api/v1/me", **bearer(r)).status_code == 401  # signed out
    # no way back in through the app: a fresh sign-in can't start verification
    c2, r2 = new_user()
    assert start(c2, r2).status_code == 403
    assert not VerificationAttempt.objects.filter(status="passed").exists()


def test_scenario_02_verification_failure_then_retry_passes():
    # (review + appeal legs are added by MC-037 / MC-038)
    c, r = new_user()
    callback(c, result(job_id_of(start(c, r)), outcome="failed", vendor_reason="doc_unreadable"))
    assert c.get("/api/v1/verification/status", **bearer(r)).json()["reason"] == "doc_unreadable"
    callback(c, result(job_id_of(start(c, r))))
    assert c.get("/api/v1/me", **bearer(r)).json()["status"] == "active"


# ---- scenario 03: concurrent duplicate interests → one row ------------------------------------
import threading  # noqa: E402
import uuid  # noqa: E402
from concurrent.futures import ThreadPoolExecutor  # noqa: E402

from django.db import connection  # noqa: E402
from django.test import Client  # noqa: E402

from mc.accounts.tests.helpers import login  # noqa: E402
from mc.interests.models import Interest  # noqa: E402
from mc.interests.tests.helpers import member, send  # noqa: E402
from mc.matches.models import Match  # noqa: E402


def _hammer(fn, n):
    barrier = threading.Barrier(n)

    def run(i):
        try:
            barrier.wait()
            return fn(i)
        finally:
            connection.close()

    with ThreadPoolExecutor(max_workers=n) as pool:
        return list(pool.map(run, range(n)))


@pytest.mark.django_db(transaction=True)
def test_scenario_03_concurrent_duplicate_interests_create_one_row():
    m, f = member("male"), member("female")
    token = m[1].json()["access"]

    def same_key(_):
        c = Client(headers={"host": "api.mc.test"})
        return c.post(
            "/api/v1/interests",
            {"recipient_id": f[3]},
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {token}",
            HTTP_IDEMPOTENCY_KEY="one-key-for-all-12345",
        ).status_code

    results = _hammer(same_key, 8)
    assert Interest.objects.count() == 1
    assert set(results) <= {200, 201, 409}  # winner 201, replays 200/201, in-flight duplicates 409
    assert 201 in results


@pytest.mark.django_db(transaction=True)
def test_scenario_03_concurrent_different_keys_still_one_pending_row():
    m, f = member("male"), member("female")
    token = m[1].json()["access"]

    def distinct_key(i):
        c = Client(headers={"host": "api.mc.test"})
        return c.post(
            "/api/v1/interests",
            {"recipient_id": f[3]},
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {token}",
            HTTP_IDEMPOTENCY_KEY=f"key-{uuid.uuid4().hex}",
        ).status_code

    results = _hammer(distinct_key, 8)
    assert Interest.objects.filter(status="pending").count() == 1 and Interest.objects.count() == 1
    assert results.count(201) == 1 and set(results) <= {201, 409}


@pytest.mark.django_db(transaction=True)
def test_scenario_03_crossing_interests_end_in_exactly_one_match():
    m, f = member("male"), member("female")
    tokens = {"m": m[1].json()["access"], "f": f[1].json()["access"]}
    targets = {"m": f[3], "f": m[3]}

    def cross(i):
        who = "m" if i % 2 == 0 else "f"
        c = Client(headers={"host": "api.mc.test"})
        return c.post(
            "/api/v1/interests",
            {"recipient_id": targets[who]},
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {tokens[who]}",
            HTTP_IDEMPOTENCY_KEY=f"cross-{uuid.uuid4().hex}",
        ).status_code

    _hammer(cross, 2)  # one from each side at the same instant
    assert Match.objects.filter(status="active").count() == 1
    assert Interest.objects.count() == 1 and Interest.objects.get().status == "accepted"
    _ = (login, send)


# ---- scenario 04: message retried after timeout → one row ---------------------------------------
@pytest.mark.django_db(transaction=True)
def test_scenario_04_message_retried_after_timeout_is_one_row():
    from mc.accounts.tests.helpers import bearer  # noqa: F401
    from mc.messaging.models import Message
    from mc.messaging.tests.helpers import matched

    m, f, mid = matched()
    token = m[1].json()["access"]
    cid = str(uuid.uuid4())

    def resend(_):
        c = Client(headers={"host": "api.mc.test"})
        return c.post(
            f"/api/v1/matches/{mid}/messages",
            {"client_msg_id": cid, "kind": "text", "body": "hello"},
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {token}",
        ).status_code

    results = _hammer(
        resend, 6
    )  # the client "timed out" and retried while the first was still in flight
    assert set(results) <= {200, 201}
    assert Message.objects.filter(kind="text").count() == 1

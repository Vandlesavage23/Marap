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

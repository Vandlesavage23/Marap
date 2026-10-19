"""v2 "About you": an unverified member declares name/gender/birth date; verification later replaces the date."""

from datetime import date, timedelta

import pytest
from django.utils import timezone

from mc.accounts.models import Account
from mc.accounts.tests.helpers import bearer
from mc.profiles.models import Profile
from mc.verification.tests.helpers import callback, job_id_of, new_user, result, start

from .helpers import patch

pytestmark = pytest.mark.django_db


def about(c, r, born="1996-03-02", **kw):
    return patch(c, r, display_name="Amani", gender="female", birth_date=born, **kw)


def test_about_you_creates_the_draft_and_readiness_asks_for_verification():
    c, r = new_user()
    resp = about(c, r)
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "draft" and body["age"] >= 18 and "birth_date" not in body
    assert "verification" in body["readiness"]["missing"]
    assert c.get("/api/v1/me/profile", **bearer(r)).status_code == 200
    assert Profile.objects.get().birth_date == date(1996, 3, 2)


def test_under_18_is_refused_kindly_and_nothing_is_created():
    c, r = new_user()
    born = (timezone.now().date() - timedelta(days=365 * 17)).isoformat()
    resp = about(c, r, born=born)
    assert resp.status_code == 403 and resp.json()["code"] == "underage"
    assert "18" in resp.json()["detail"] and Profile.objects.count() == 0
    assert Account.objects.get().status == "pending_verification"  # no suspension for a typo
    assert about(c, r, born="1850-01-01").status_code == 422


def test_birth_date_is_editable_until_verified_then_the_id_wins(django_capture_on_commit_callbacks):
    c, r = new_user()
    about(c, r, born="2000-01-01")
    assert patch(c, r, birth_date="1999-05-05").status_code == 200
    with django_capture_on_commit_callbacks(execute=True):
        callback(c, result(job_id_of(start(c, r)), id_number="UG-ABOUT-1"))  # ID says 1995-05-17
    assert Profile.objects.get().birth_date == date(1995, 5, 17)
    assert patch(c, r, birth_date="1990-01-01").status_code == 422
    assert patch(c, r, birth_date="1995-05-17").status_code == 200  # a no-op is fine
    assert Profile.objects.get().birth_date == date(1995, 5, 17)


def test_unverified_member_cannot_use_other_profile_endpoints_or_go_live():
    c, r = new_user()
    about(c, r)
    assert c.post("/api/v1/me/profile/go-live", **bearer(r)).status_code == 403
    assert c.get("/api/v1/me/photos", **bearer(r)).status_code == 403
    assert c.get("/api/v1/me/descriptions", **bearer(r)).status_code == 403
    assert Profile.objects.get().status == "draft"


def test_married_rule_is_unchanged_for_the_about_you_step():
    c, r = new_user()
    resp = about(c, r, marital_status="married_customary")
    assert resp.status_code == 422 and resp.json()["code"] == "married_not_eligible"

"""`GET /me/entitlements` v2 blocks and the trial/reminder behaviour around the new free tier."""

import uuid
from datetime import timedelta

import pytest
from django.utils import timezone

from devtools.factories import create_member
from mc.accounts.tests.helpers import bearer
from mc.entitlements import selectors, services, tasks
from mc.entitlements.models import Entitlement, Trial
from mc.interests.tests.helpers import member, send
from mc.verification.tests.helpers import new_user

from .test_entitlements import start_trial_http, unverified, verified

pytestmark = pytest.mark.django_db


def get(c, r):
    resp = c.get("/api/v1/me/entitlements", **bearer(r))
    assert resp.status_code == 200
    return resp.json()


def test_unverified_member_payload():
    c, r = new_user()
    body = get(c, r)
    assert body["state"] == "none"
    assert body["verification"] == {"status": "not_started", "verified": False}
    assert body["trial"] == {"used": False, "available": False, "started_at": None, "ends_at": None}
    assert body["browse"]["limit"] == 30 and body["browse"]["used"] == 0
    assert body["browse"]["resets_at"].endswith("Z")
    assert body["profile_opens"]["limit"] == 10
    assert body["interests"] == {
        "limit": 3,
        "used": 0,
        "resets_at": None,
        "period": "rolling_7_days",
    }
    caps = body["capabilities"]
    assert caps["browse"] and caps["account_controls"] and not caps["send_interest"]


def test_verified_free_member_payload_tracks_usage():
    m = member("male", trial=False)
    w = [member("female") for _ in range(2)]
    send(m[0], m[1], w[0][3])
    body = get(m[0], m[1])
    assert body["interests"]["limit"] == 3 and body["interests"]["used"] == 1
    assert body["interests"]["resets_at"].endswith("Z")
    assert body["browse"]["limit"] == 60
    assert body["profile_opens"]["limit"] is None
    assert body["trial"]["available"] is True and body["verification"]["verified"] is True
    assert body["verification"]["status"] in (
        "passed",
        "not_started",
    )  # factory member has a passed attempt


def test_trial_member_and_expired_payloads():
    c, r, acct = verified()
    resp = start_trial_http(c, r)
    body = resp.json()
    assert body["trial"]["available"] is False and body["trial"]["started_at"].endswith("Z")
    assert body["interests"]["limit"] == 20 and body["interests"]["period"] == "day"
    assert body["browse"]["limit"] is None
    Entitlement.objects.filter(account=acct).update(
        starts_at=timezone.now() - timedelta(days=3), ends_at=timezone.now() - timedelta(days=2)
    )
    body = get(c, r)
    assert body["state"] == "expired" and body["browse"]["limit"] == 60
    assert body["trial"]["used"] is True and body["trial"]["available"] is False
    services.grant(
        account=acct,
        ends_at=timezone.now() + timedelta(days=30),
        reason="x",
        actor_id=uuid.uuid4(),
        actor_role="support",
    )
    body = get(c, r)
    assert body["state"] == "member" and body["interests"]["limit"] == 30 and body["membership"]


def test_trial_available_is_false_when_the_same_person_already_used_it():
    _, _, first = verified("+256772000001", id_number="SAME-1")
    services.start_trial(account=first)
    from mc.accounts import services as account_services

    account_services.hard_delete_account(account=first)
    _, _, again = verified("+256772000002", id_number="same 1")
    assert selectors.can_start_trial(again) is False
    assert Trial.objects.count() == 1


def test_verification_status_reflects_the_latest_attempt():
    from mc.verification.tests.helpers import start

    c, r = new_user()
    start(c, r)
    assert get(c, r)["verification"] == {"status": "created", "verified": False}


def test_endpoint_is_forbidden_without_auth_or_for_suspended_accounts():
    from django.test import Client

    assert Client(headers={"host": "api.mc.test"}).get("/api/v1/me/entitlements").status_code == 401
    c, r = new_user("+256772000077")
    from mc.accounts.models import Account

    Account.objects.filter(phone_e164="+256772000077").update(status="suspended")
    assert c.get("/api/v1/me/entitlements", **bearer(r)).status_code == 403


def test_browse_card_and_open_limits_by_state():
    st = selectors.entitlement_summary
    unv = unverified()[2]
    assert (
        selectors.browse_card_limit(st(unv)) == 30 and selectors.profile_open_limit(st(unv)) == 10
    )
    free = create_member(gender="male")
    assert (
        selectors.browse_card_limit(st(free)) == 60
        and selectors.profile_open_limit(st(free)) is None
    )
    services.start_trial(account=free)
    assert selectors.browse_card_limit(st(free)) is None


def test_trial_ended_reminder_is_skipped_once_the_member_pays(django_capture_on_commit_callbacks):
    from mc.common import events
    from mc.entitlements.events import TrialReminderDue

    got = []
    events.subscribe(TrialReminderDue)(got.append)
    _, _, acct = verified()
    services.start_trial(account=acct)
    Trial.objects.filter(account=acct).update(ends_at=timezone.now() - timedelta(minutes=1))
    services.grant(
        account=acct,
        ends_at=timezone.now() + timedelta(days=30),
        reason="paid",
        actor_id=uuid.uuid4(),
        actor_role="support",
    )
    with django_capture_on_commit_callbacks(execute=True):
        tasks.send_trial_reminder(str(acct.id), "ended")
    assert got == []


def test_trial_ended_notification_no_longer_implies_browsing_stops():
    from mc.notifications.catalog import CATALOG

    body = str(CATALOG["trial_ended"]["body"])
    assert "still browse" in body and "chat" in body

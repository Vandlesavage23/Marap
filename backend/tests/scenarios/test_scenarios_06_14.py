"""Scenarios 06, 08-11 (Phase 5, skipped) and 14 (fault injection) — Bible §13.2."""

from datetime import timedelta

import pytest
import redis.exceptions
from django.db import OperationalError
from django.utils import timezone

from mc.accounts.tests.helpers import bearer
from mc.entitlements.models import Entitlement
from mc.interests.models import Interest
from mc.interests.tests.helpers import member, send
from mc.messaging.models import Message
from mc.messaging.tests.helpers import history, matched, say
from mc.notifications.providers.push import FakePush

pytestmark = pytest.mark.django_db


def test_scenario_06_membership_expires_mid_conversation_read_only_no_data_loss(settings):
    """Bible §13.2 scenario 06. v2 (ADR-0009): chat inside a match stays free after the membership ends
    (`FREE_CHAT_IN_MATCH`); the original read-only behaviour is what the flag-off setting still gives."""
    settings.FREE_CHAT_IN_MATCH = False
    m, f, mid = matched()
    assert say(m, mid, "before expiry").status_code == 201
    now = timezone.now()
    Entitlement.objects.filter(account=m[2]).update(
        starts_at=now - timedelta(days=2), ends_at=now - timedelta(minutes=1)
    )
    resp = say(m, mid, "after expiry")
    assert resp.status_code == 403 and resp.json()["code"] == "entitlement_required"
    assert Message.objects.filter(match_id=mid).count() >= 1  # nothing deleted
    mine = history(m, mid)  # read-only: the expired member can still read what was said
    assert mine.status_code == 200 and "before expiry" in str(mine.json())
    # the other (still entitled) member keeps the full history
    bodies = [x.get("body") for x in history(f, mid).json()["items"]]
    assert "before expiry" in bodies
    assert say(f, mid, "still here").status_code == 201
    settings.FREE_CHAT_IN_MATCH = True  # v2 default: the expired member may keep talking
    assert say(m, mid, "after expiry, free chat").status_code == 201


@pytest.mark.skip(
    reason="Phase 5 feature (CLAUDE.md rule 12): not built until a backlog ticket says so"
)
@pytest.mark.parametrize("n", [8, 9, 10, 11])
def test_scenario_08_11_phase5(n):
    raise AssertionError(n)


# ---- scenario 14: outages degrade gracefully, nothing is half-written, retries succeed -----------------
def test_scenario_14_redis_outage_is_a_clean_503_then_recovers(monkeypatch):
    from mc.common import ratelimit

    def boom(*a, **k):
        raise redis.exceptions.ConnectionError("redis down")

    monkeypatch.setattr(ratelimit, "get_redis", boom)
    from django.test import Client

    r = Client(headers={"host": "api.mc.test"}).post(
        "/api/v1/auth/otp/start", {"phone": "+256772123456"}, content_type="application/json"
    )
    assert r.status_code == 503 and r["Content-Type"].startswith("application/problem+json")
    assert r.json()["code"] == "service_unavailable" and r["Retry-After"] == "5"
    monkeypatch.undo()
    r = Client(headers={"host": "api.mc.test"}).post(
        "/api/v1/auth/otp/start", {"phone": "+256772123456"}, content_type="application/json"
    )
    assert r.status_code in (200, 202, 204)


def test_scenario_14_database_error_mid_request_rolls_back_and_retry_succeeds(monkeypatch):
    m, f, mid = matched()
    from mc.matches import services as match_services

    real = match_services.record_participant_message
    calls = {"n": 0}

    def flaky(*a, **k):
        calls["n"] += 1
        if calls["n"] == 1:
            raise OperationalError("connection dropped")
        return real(*a, **k)

    monkeypatch.setattr(match_services, "record_participant_message", flaky)
    cid = "11111111-1111-4111-8111-111111111111"
    r1 = say(m, mid, "important", cid=cid)
    assert r1.status_code == 503 and r1.json()["code"] == "service_unavailable"
    assert (
        Message.objects.filter(match_id=mid, client_msg_id=cid).count() == 0
    )  # rolled back, not half-written
    r2 = say(m, mid, "important", cid=cid)  # same client id → the retry works, exactly one row
    assert r2.status_code == 201
    assert Message.objects.filter(match_id=mid, client_msg_id=cid).count() == 1


def test_scenario_14_push_vendor_outage_never_blocks_or_corrupts_the_action():
    FakePush.fail = True
    a, b = member("male"), member("female")
    r = send(a[0], a[1], b[3])
    assert r.status_code == 201 and Interest.objects.filter(status="pending").count() == 1
    FakePush.fail = False


def test_scenario_14_identity_vendor_outage_is_a_502_and_leaves_no_stuck_attempt(monkeypatch):
    from mc.verification.providers import fake
    from mc.verification.tests.helpers import new_user, start

    def down(self, **kw):
        from mc.common.errors import ProviderError

        raise ProviderError("vendor down")

    monkeypatch.setattr(fake.FakeIdentityProvider, "create_job", down)
    c, r = new_user()
    resp = start(c, r)
    assert resp.status_code == 502 and resp.json()["code"] == "provider_error"
    monkeypatch.undo()
    assert start(c, r).status_code in (200, 201)  # retry works; nothing blocked


_ = bearer

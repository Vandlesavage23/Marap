"""Free-tier interest quota (docs/design/user-flow-v2.md §4.2): rolling 7 days, atomic with the send, replays and
accepts never consume, trial/member are exempt, and every problem code carries what the app needs."""

import threading
import uuid
from concurrent.futures import ThreadPoolExecutor
from datetime import timedelta

import pytest
from django.db import connection
from django.test import Client
from django.utils import timezone
from freezegun import freeze_time

from mc.accounts.tests.helpers import bearer
from mc.common.errors import InterestQuotaReached
from mc.common.redis import get_redis
from mc.entitlements import selectors as ent_selectors
from mc.entitlements import services as ent
from mc.interests import selectors
from mc.interests import services as interest_services
from mc.interests.models import Interest

from .helpers import J, member, send

pytestmark = pytest.mark.django_db
WEEK = timedelta(days=7)


def targets(n, *, gender="female"):
    return [member(gender) for _ in range(n)]


def free_sender():
    return member("male", trial=False)


def svc_send(sender, target):
    """Service-level send (no HTTP): lets tests move the clock further than an access token lives."""
    return interest_services.send_interest(
        sender=sender, recipient_profile_id=uuid.UUID(target[3]), idempotency_key=uuid.uuid4().hex
    )


def quota_error(sender, target) -> InterestQuotaReached:
    with pytest.raises(InterestQuotaReached) as info:
        svc_send(sender, target)
    return info.value


def used(acct, state="none"):
    return selectors.allowance(acct.id, state=state, now=timezone.now())


# ---- the quota itself -----------------------------------------------------------------------------
def test_free_member_can_send_exactly_the_weekly_quota_then_gets_the_quota_problem():
    m = free_sender()
    t = targets(4)
    for i in range(3):
        resp = send(m[0], m[1], t[i][3])
        assert resp.status_code == 201
        assert resp.json()["remaining_quota"] == 2 - i
    blocked = send(m[0], m[1], t[3][3])
    body = blocked.json()
    assert blocked.status_code == 403
    assert blocked["Content-Type"].startswith("application/problem+json")
    assert body["code"] == "interest_quota_reached"
    assert body["limit"] == 3 and body["can_start_trial"] is True
    assert body["resets_at"].endswith("Z")
    assert Interest.objects.count() == 3
    # nothing about the recipient was revealed or created
    assert not Interest.objects.filter(recipient=t[3][2]).exists()


def test_resets_at_is_when_the_oldest_interest_leaves_the_window_and_the_boundary_is_exact():
    m = free_sender()
    t = targets(5)
    with freeze_time("2026-04-01 08:00:00") as clock:
        svc_send(m[2], t[0])  # day 0
        clock.tick(timedelta(days=1))
        svc_send(m[2], t[1])  # day 1
        clock.tick(timedelta(days=1))
        svc_send(m[2], t[2])  # day 2
        err = quota_error(m[2], t[3])
        assert err.extra["resets_at"] == "2026-04-08T08:00:00Z"  # first interest + 7 d
        assert err.extra["limit"] == 3 and err.extra["can_start_trial"] is True
        clock.tick(timedelta(days=4, hours=23, minutes=59, seconds=59))  # 2026-04-08 07:59:59
        assert quota_error(m[2], t[3]).extra["resets_at"] == "2026-04-08T08:00:00Z"
        clock.tick(timedelta(seconds=1))  # exactly 7 days after the first send
        svc_send(m[2], t[3])
        err = quota_error(m[2], t[4])
        assert (
            err.extra["resets_at"] == "2026-04-09T08:00:00Z"
        )  # the NEXT one to leave: the day-1 interest


def test_quota_is_a_rolling_window_not_a_calendar_week():
    m = free_sender()
    t = targets(4)
    with freeze_time("2026-04-05 23:59:00") as clock:  # a Sunday night
        for i in range(3):
            svc_send(m[2], t[i])
        clock.tick(timedelta(minutes=2))  # Monday morning: a calendar week would have reset
        assert quota_error(m[2], t[3]).extra["limit"] == 3


def test_quota_configuration_is_honoured(settings):
    settings.FREE_INTERESTS_PER_WEEK = 1
    settings.FREE_INTERESTS_WINDOW_DAYS = 2
    m = free_sender()
    t = targets(2)
    with freeze_time("2026-04-01 08:00:00") as clock:
        svc_send(m[2], t[0])
        err = quota_error(m[2], t[1])
        assert err.extra["limit"] == 1 and err.extra["resets_at"] == "2026-04-03T08:00:00Z"
        clock.tick(timedelta(days=2))
        svc_send(m[2], t[1])


def test_a_limit_of_zero_never_crashes_and_always_blocks(settings):
    settings.FREE_INTERESTS_PER_WEEK = 0
    m = free_sender()
    (t,) = targets(1)
    body = send(m[0], m[1], t[3]).json()
    assert body["code"] == "interest_quota_reached" and body["limit"] == 0
    assert body["resets_at"] is None  # nothing used yet, so nothing will free up


# ---- what counts / what doesn't ------------------------------------------------------------------------
def test_idempotent_replay_does_not_consume_quota_even_without_the_redis_cache():
    m = free_sender()
    (t,) = targets(1)
    first = send(m[0], m[1], t[3], key="quota-replay-key-1")
    assert first.status_code == 201
    second = send(m[0], m[1], t[3], key="quota-replay-key-1")  # served from the idempotency cache
    assert second.json() == first.json() and second["Idempotent-Replayed"] == "true"
    for key in get_redis().scan_iter("idem:*"):
        get_redis().delete(key)  # force the database-level replay path too
    third = send(m[0], m[1], t[3], key="quota-replay-key-1")
    assert third.status_code == 200 and third.json()["id"] == first.json()["id"]
    assert third.json()["remaining_quota"] == 2
    assert Interest.objects.count() == 1 and used(m[2]).used == 1


def test_a_replay_still_succeeds_when_the_quota_is_already_exhausted():
    m = free_sender()
    t = targets(3)
    keys = [f"quota-key-{i}-abcdef" for i in range(3)]
    for k, tt in zip(keys, t, strict=True):
        assert send(m[0], m[1], tt[3], key=k).status_code == 201
    for key in get_redis().scan_iter("idem:*"):
        get_redis().delete(key)
    again = send(m[0], m[1], t[0][3], key=keys[0])
    assert again.status_code == 200 and again.json()["status"] == "pending"


def test_accepting_an_interest_that_is_waiting_for_you_costs_no_quota():
    m = free_sender()
    for tt in targets(3):
        assert send(m[0], m[1], tt[3]).status_code == 201
    assert used(m[2]).used == 3 and used(m[2]).exhausted
    w = member("female")
    assert send(w[0], w[1], m[3]).status_code == 201  # w -> m, pending
    resp = send(m[0], m[1], w[3])  # m "sends" back while out of quota: that is an accept
    assert (
        resp.status_code == 200 and resp.json()["status"] == "accepted" and resp.json()["match_id"]
    )
    assert used(m[2]).used == 3  # no row was created for the accept


def test_explicit_accept_endpoint_is_free_for_free_members():
    from .helpers import accept

    w = member("female")
    m = free_sender()
    iid = send(w[0], w[1], m[3]).json()["id"]
    assert accept(m[0], m[1], iid).status_code == 200


def test_errors_before_the_quota_do_not_leak_or_consume():
    m = free_sender()
    t = targets(3)
    for tt in t:
        send(m[0], m[1], tt[3])
    stranger_same_gender = member("male")
    missing = send(m[0], m[1], str(uuid.uuid4()))
    # an unknown / ineligible recipient is `not_eligible` whether or not the quota is used up
    assert missing.status_code == 403 and missing.json()["code"] == "not_eligible"
    assert (
        send(m[0], m[1], stranger_same_gender[3]).json()["code"] == "not_eligible"
    )  # same gender: filters apply before the quota
    dup = send(m[0], m[1], t[0][3]).json()
    assert dup["code"] == "duplicate"


def test_blocked_pair_is_not_eligible_not_quota_even_when_exhausted():
    from mc.safety import services as safety

    m = free_sender()
    t = targets(4)
    for tt in t[:3]:
        send(m[0], m[1], tt[3])
    safety.block(blocker=t[3][2], blocked_id=m[2].id)
    assert send(m[0], m[1], t[3][3]).json()["code"] == "not_eligible"


# ---- who is exempt ---------------------------------------------------------------------------------------
def test_trial_and_member_have_no_weekly_quota_only_the_daily_cap():
    t = targets(5)
    trial = member("male", trial=True)
    for tt in t:
        assert send(trial[0], trial[1], tt[3]).status_code == 201
    assert used(trial[2], "trial").limit == 20 and used(trial[2], "trial").period == "day"
    t2 = targets(4)
    paying = free_sender()
    ent.grant(
        account=paying[2],
        ends_at=timezone.now() + timedelta(days=30),
        reason="test",
        actor_id=uuid.uuid4(),
        actor_role="support",
    )
    for tt in t2:
        assert send(paying[0], paying[1], tt[3]).status_code == 201
    assert used(paying[2], "member").limit == 30


def test_after_the_trial_the_account_is_back_on_the_weekly_quota_counting_recent_sends():
    t = targets(5)
    m = member("male", trial=False)
    with freeze_time(timezone.now()) as clock:
        ent.start_trial(account=m[2])
        for tt in t[:3]:
            svc_send(m[2], tt)
        clock.tick(timedelta(hours=25))  # trial over
        assert ent_selectors.entitlement_summary(m[2]).state == "expired"
        err = quota_error(m[2], t[3])
        assert err.extra["can_start_trial"] is False  # the trial was used


def test_can_start_trial_is_true_only_while_the_trial_is_unused():
    m = free_sender()
    t = targets(4)
    for tt in t[:3]:
        send(m[0], m[1], tt[3])
    assert send(m[0], m[1], t[3][3]).json()["can_start_trial"] is True
    ent.start_trial(account=m[2])
    assert send(m[0], m[1], t[3][3]).status_code == 201  # starting the trial lifts the weekly quota


def test_unverified_sender_gets_verification_required_and_consumes_nothing():
    m = member("male", trial=False, verified=False, live=False)
    (t,) = targets(1)
    resp = send(m[0], m[1], t[3])
    body = resp.json()
    assert resp.status_code == 403 and body["code"] == "verification_required"
    assert body["capability"] == "send_interest"
    assert Interest.objects.count() == 0
    # same answer for an id that does not exist: nothing about recipients is revealed
    assert send(m[0], m[1], str(uuid.uuid4())).json()["code"] == "verification_required"


def test_forbidden_without_auth_and_idempotency_key():
    assert (
        Client(headers={"host": "api.mc.test"}).post("/api/v1/interests", {}, **J).status_code
        == 401
    )


# ---- races -------------------------------------------------------------------------------------------------
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
def test_parallel_sends_to_different_people_never_exceed_the_quota():
    m = free_sender()
    t = targets(8)
    token = m[1].json()["access"]

    def go(i):
        c = Client(headers={"host": "api.mc.test"})
        return c.post(
            "/api/v1/interests",
            {"recipient_id": t[i][3]},
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {token}",
            HTTP_IDEMPOTENCY_KEY=f"race-{i}-{uuid.uuid4().hex}",
        )

    results = _hammer(go, 8)
    codes = [r.status_code for r in results]
    assert codes.count(201) == 3 and codes.count(403) == 5, codes
    assert {r.json()["code"] for r in results if r.status_code == 403} == {"interest_quota_reached"}
    assert Interest.objects.filter(sender=m[2]).count() == 3


@pytest.mark.django_db(transaction=True)
def test_parallel_sends_with_one_slot_left_create_exactly_one_interest():
    m = free_sender()
    t = targets(6)
    for tt in t[:2]:
        assert send(m[0], m[1], tt[3]).status_code == 201
    token = m[1].json()["access"]

    def go(i):
        c = Client(headers={"host": "api.mc.test"})
        return c.post(
            "/api/v1/interests",
            {"recipient_id": t[2 + i % 4][3]},
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {token}",
            HTTP_IDEMPOTENCY_KEY=f"last-{i}-{uuid.uuid4().hex}",
        ).status_code

    codes = _hammer(go, 8)
    assert codes.count(201) == 1 and set(codes) <= {201, 403, 409}, codes
    assert Interest.objects.filter(sender=m[2]).count() == 3


# ---- allowance selector ------------------------------------------------------------------------------------
def test_allowance_reports_usage_and_the_next_slot():
    m = free_sender()
    t = targets(3)
    with freeze_time("2026-06-01 10:00:00") as clock:
        assert used(m[2]) == selectors.Allowance(3, 0, None, "rolling_7_days")
        svc_send(m[2], t[0])
        clock.tick(timedelta(hours=1))
        svc_send(m[2], t[1])
        a = used(m[2])
        assert (a.limit, a.used, a.period) == (3, 2, "rolling_7_days")
        assert a.resets_at == timezone.now() - timedelta(hours=1) + WEEK  # when the oldest leaves
        assert not a.exhausted


def test_every_member_can_still_receive_and_read_interests_without_quota_or_trial():
    """Free is honest: received interests are never locked (§1 principle 4)."""
    w = member("female")
    m = free_sender()
    iid = send(w[0], w[1], m[3]).json()["id"]
    resp = m[0].get("/api/v1/interests/received", **bearer(m[1]))
    assert resp.status_code == 200
    item = resp.json()["items"][0]
    assert item["id"] == iid and item["snapshot"]["text"] and item["sender"]["display_name"]

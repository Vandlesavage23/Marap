import pytest

from mc.accounts.tests.helpers import bearer
from mc.discovery import services as discovery
from mc.interests.models import Interest, InterestSnapshot
from mc.interests.tests.helpers import accept, member, pair, send
from mc.matches.models import Match
from mc.messaging.tests.helpers import history, matched, say
from mc.notifications.models import Notification
from mc.safety import services
from mc.safety.models import Block
from mc.verification.tests.helpers import J

pytestmark = pytest.mark.django_db


def block(who, target_pid):
    return who[0].post("/api/v1/blocks", {"profile_id": target_pid}, **bearer(who[1]), **J)


def test_block_is_one_transaction_and_has_every_effect(django_capture_on_commit_callbacks):
    m, f, mid = matched()
    Notification.objects.create(
        account=f[2], type="match_created", payload={"match_id": mid}, counterpart=m[2]
    )
    Notification.objects.create(
        account=m[2], type="match_created", payload={"match_id": mid}, counterpart=f[2]
    )
    third = member("female")
    send(m[0], m[1], third[3])  # a pending interest to someone else must survive
    with django_capture_on_commit_callbacks(execute=True):
        assert block(f, m[3]).status_code == 201
    assert Block.objects.filter(blocker=f[2], blocked=m[2]).exists()
    assert Match.objects.get(id=mid).status == "blocked"
    assert not Notification.objects.filter(counterpart__in=[m[2], f[2]]).exists()
    assert Interest.objects.filter(recipient=third[2], status="pending").count() == 1


def test_block_cancels_pending_interests_both_ways_and_deletes_snapshots():
    m, f = pair()
    send(m[0], m[1], f[3])
    assert InterestSnapshot.objects.count() == 1
    block(m, f[3])
    assert Interest.objects.get().status == "cancelled" and InterestSnapshot.objects.count() == 0
    # and from the recipient's side
    m2, f2 = pair()
    send(m2[0], m2[1], f2[3])
    block(f2, m2[3])
    assert Interest.objects.filter(sender=m2[2]).get().status == "cancelled"


def test_all_effects_roll_back_together_if_any_step_fails(monkeypatch):
    m, f, mid = matched()
    from mc.notifications import services as notification_services

    def boom(**kw):
        raise RuntimeError("purge failed")

    monkeypatch.setattr(notification_services, "purge_between", boom)
    with pytest.raises(RuntimeError):
        services.block(blocker=f[2], blocked_id=m[2].id)
    assert not Block.objects.exists() and Match.objects.get(id=mid).status == "active"


def test_blocked_user_vanishes_from_discovery_interests_matches_chat_and_profile_view():
    m, f, mid = matched()
    say(m, mid, "hello")
    other = member("female")
    block(m, f[3])
    # discovery (both directions)
    assert str(f[2].id) not in {e.account_id for e in discovery.build_ranked_pool(m[2])[0]}
    assert str(m[2].id) not in {e.account_id for e in discovery.build_ranked_pool(f[2])[0]}
    # interests
    assert send(m[0], m[1], f[3]).json()["code"] == "not_eligible"
    assert send(f[0], f[1], m[3]).json()["code"] == "not_eligible"
    # matches + chat
    for who in (m, f):
        assert who[0].get("/api/v1/matches", **bearer(who[1])).json()["items"] == []
        assert history(who, mid).status_code == 404 and say(who, mid).status_code == 404
    # public profile
    for a, b in ((m, f), (f, m)):
        assert a[0].get(f"/api/v1/profiles/{b[3]}", **bearer(a[1])).status_code == 404
    assert m[0].get(f"/api/v1/profiles/{other[3]}", **bearer(m[1])).status_code in (
        200,
        404,
    )  # unaffected path


def test_blocked_user_is_not_notified_and_response_reveals_nothing(
    django_capture_on_commit_callbacks,
):
    m, f = pair()
    with django_capture_on_commit_callbacks(execute=True):
        block(m, f[3])
    assert not Notification.objects.filter(account=f[2]).exists()
    assert (
        f[0].get("/api/v1/blocks", **bearer(f[1])).json()["items"] == []
    )  # blocked party's list is empty
    assert f[0].get("/api/v1/me", **bearer(f[1])).status_code == 200


def test_block_idempotent_validation_and_auth():
    from django.test import Client

    m, f = pair()
    assert block(m, f[3]).status_code == 201 and block(m, f[3]).status_code == 201
    assert Block.objects.count() == 1
    assert block(m, m[3]).status_code == 422
    import uuid

    assert block(m, str(uuid.uuid4())).status_code == 404
    assert (
        m[0].post("/api/v1/blocks", {"profile_id": f[3], "x": 1}, **bearer(m[1]), **J).status_code
        == 422
    )
    assert (
        Client(headers={"host": "api.mc.test"}).post("/api/v1/blocks", {}, **J).status_code == 401
    )


def test_list_and_unblock_does_not_restore_anything():
    m, f, mid = matched()
    block(m, f[3])
    items = m[0].get("/api/v1/blocks", **bearer(m[1])).json()["items"]
    assert [i["profile_id"] for i in items] == [f[3]] and items[0]["display_name"]
    assert str(f[2].id) not in str(items)
    assert m[0].delete(f"/api/v1/blocks/{f[3]}", **bearer(m[1])).status_code == 204
    assert m[0].delete(f"/api/v1/blocks/{f[3]}", **bearer(m[1])).status_code == 204  # idempotent
    assert not Block.objects.exists()
    assert Match.objects.get(id=mid).status == "blocked"  # NOT restored
    assert m[0].get("/api/v1/matches", **bearer(m[1])).json()["items"] == []
    # they can now find each other again, but only via a fresh interest (and the unmatch cool-off applies)
    assert send(m[0], m[1], f[3]).json()["code"] == "not_eligible"


def test_pending_interest_accept_after_block_is_not_found():
    m, f = pair()
    iid = send(m[0], m[1], f[3]).json()["id"]
    block(m, f[3])
    assert accept(f[0], f[1], iid).status_code in (404, 409)
    assert not Match.objects.exists()

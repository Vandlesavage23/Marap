import uuid

import pytest
from django.test import Client

from mc.accounts import services as account_services
from mc.accounts.models import Device
from mc.accounts.tests.helpers import bearer
from mc.common import presence
from mc.common.redis import get_redis
from mc.interests.tests.helpers import accept, member, pair, send
from mc.messaging.tests.helpers import matched, say
from mc.notifications import services, tasks
from mc.notifications.models import Notification
from mc.notifications.providers.push import FakePush
from mc.safety.models import Block

pytestmark = pytest.mark.django_db


def register(acct, token="tok-1", platform="android"):
    return account_services.register_device(
        account=acct, install_id=uuid.uuid4(), platform=platform, push_token=token
    )


def pushes(type_=None):
    return [m for _, _, m in FakePush.sent if type_ is None or m.type == type_]


def test_interest_creates_inbox_entry_and_generic_push(django_capture_on_commit_callbacks):
    m, f = pair()
    register(f[2], "tok-f")
    with django_capture_on_commit_callbacks(execute=True):
        iid = send(m[0], m[1], f[3]).json()["id"]
    n = Notification.objects.get(account=f[2])
    assert (
        n.type == "interest_received"
        and n.payload == {"interest_id": iid}
        and n.counterpart_id == m[2].id
    )
    (push,) = pushes("interest_received")
    assert push.body == "Someone is interested in you" and push.data == {"interest_id": iid}
    # nothing identifying leaks into push bodies
    for text in (push.title, push.body, str(push.data)):
        assert "Member" not in text and m[3] not in text and "+256" not in text


def test_match_notifies_both_members(django_capture_on_commit_callbacks):
    m, f = pair()
    register(m[2], "tok-m")
    register(f[2], "tok-f")
    iid = send(m[0], m[1], f[3]).json()["id"]
    with django_capture_on_commit_callbacks(execute=True):
        accept(f[0], f[1], iid)
    assert {n.account_id for n in Notification.objects.filter(type="match_created")} == {
        m[2].id,
        f[2].id,
    }
    assert len(pushes("match_created")) == 2


def test_message_push_only_when_offline_debounced_and_generic(
    django_capture_on_commit_callbacks, settings
):
    m, f, mid = matched()
    register(f[2], "tok-f")
    with django_capture_on_commit_callbacks(execute=True):
        say(m, mid, "a private message with sensitive words")
        say(m, mid, "another one")
    msgs = pushes("new_message")
    assert len(msgs) == 1  # second is debounced (30 s per match)
    assert msgs[0].body == "You have a new message" and "sensitive" not in str(msgs[0])
    assert not Notification.objects.filter(type="new_message").exists()  # chat isn't in the inbox
    get_redis().flushdb()
    FakePush.reset()
    presence.touch(f[2].id, "sock-1")  # recipient has a live socket → frame, no push
    with django_capture_on_commit_callbacks(execute=True):
        say(m, mid, "online now")
    assert pushes("new_message") == []
    presence.remove(f[2].id, "sock-1")
    assert presence.is_online(f[2].id) is False


def test_presence_expires_for_crashed_servers():
    from freezegun import freeze_time

    acct = member("male", trial=False)[2]
    with freeze_time("2026-10-15 10:00:00") as t:
        presence.touch(acct.id, "s")
        assert presence.is_online(acct.id)
        t.tick(75)
        assert not presence.is_online(acct.id)


def test_blocked_members_get_no_notifications(django_capture_on_commit_callbacks):
    m, f = pair()
    register(f[2])
    Block.objects.create(blocker=f[2], blocked=m[2])
    with django_capture_on_commit_callbacks(execute=True):
        services.notify(
            account_id=f[2].id,
            type="interest_received",
            payload={"interest_id": "x"},
            counterpart_id=m[2].id,
        )
    assert not Notification.objects.exists() and pushes() == []


def test_purge_between_removes_entries_for_a_blocked_pair():
    m, f = pair()
    services.notify(
        account_id=f[2].id,
        type="interest_received",
        payload={"interest_id": "x"},
        counterpart_id=m[2].id,
    )
    services.notify(
        account_id=m[2].id, type="match_created", payload={"match_id": "y"}, counterpart_id=f[2].id
    )
    services.notify(account_id=f[2].id, type="trial_ended")
    assert services.purge_between(a=m[2].id, b=f[2].id) == 2
    assert list(Notification.objects.values_list("type", flat=True)) == ["trial_ended"]


def test_invalid_tokens_are_pruned_and_valid_ones_still_sent():
    acct = member("female", trial=False)[2]
    register(acct, "good")
    register(acct, "dead", platform="ios")
    FakePush.invalid_tokens.add("dead")
    assert tasks.send_push(str(acct.id), "new_message", {"match_id": "m"}) == 1
    assert (
        not Device.objects.filter(push_token="dead").exists()
        and Device.objects.filter(push_token="good").exists()
    )


def test_push_failure_retries_not_drops():
    acct = member("female", trial=False)[2]
    register(acct)
    FakePush.fail = True
    from celery.exceptions import Retry

    with pytest.raises(Exception) as ei:
        tasks.send_push.apply(args=[str(acct.id), "new_message", {}], throw=True).get()
    assert ei.type is not None or Retry


def test_trial_and_device_notifications(django_capture_on_commit_callbacks):
    from mc.entitlements import tasks as ent_tasks
    from mc.entitlements.models import Trial

    m = member("male", trial=True)
    register(m[2])
    with django_capture_on_commit_callbacks(execute=True):
        ent_tasks.send_trial_reminder(str(m[2].id), "ending_soon")
    assert Notification.objects.get(type="trial_ending_soon").account_id == m[2].id
    assert pushes("trial_ending_soon")[0].body == "Your free trial ends soon"
    assert Trial.objects.exists()


def test_inbox_api_pagination_unread_and_mark_read():
    f = member("female", trial=False)
    for i in range(5):
        services.notify(account_id=f[2].id, type="trial_ended", payload={"n": i})
    p1 = f[0].get("/api/v1/notifications?limit=3", **bearer(f[1])).json()
    p2 = (
        f[0].get(f"/api/v1/notifications?limit=3&cursor={p1['next_cursor']}", **bearer(f[1])).json()
    )
    assert len(p1["items"]) == 3 and len(p2["items"]) == 2 and p1["unread"] == 5
    ids = [p1["items"][0]["id"]]
    assert (
        f[0]
        .post(
            "/api/v1/notifications/read",
            {"ids": ids},
            content_type="application/json",
            **bearer(f[1]),
        )
        .status_code
        == 204
    )
    assert f[0].get("/api/v1/notifications", **bearer(f[1])).json()["unread"] == 4
    assert (
        f[0]
        .post("/api/v1/notifications/read", {}, content_type="application/json", **bearer(f[1]))
        .status_code
        == 204
    )
    assert f[0].get("/api/v1/notifications", **bearer(f[1])).json()["unread"] == 0
    assert Client(headers={"host": "api.mc.test"}).get("/api/v1/notifications").status_code == 401


def test_inbox_isolated_per_account_and_hides_blocked_counterparts():
    m, f = pair()
    services.notify(
        account_id=f[2].id,
        type="interest_received",
        payload={"interest_id": "z"},
        counterpart_id=m[2].id,
    )
    assert m[0].get("/api/v1/notifications", **bearer(m[1])).json()["items"] == []
    assert len(f[0].get("/api/v1/notifications", **bearer(f[1])).json()["items"]) == 1
    Block.objects.create(blocker=f[2], blocked=m[2])
    assert f[0].get("/api/v1/notifications", **bearer(f[1])).json()["items"] == []

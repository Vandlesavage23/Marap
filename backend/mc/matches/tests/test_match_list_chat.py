"""GET /matches carries chat activity (last_message_at, unread_count, kind/sender) but never message text."""

import pytest
from django.db import connection
from django.test.utils import CaptureQueriesContext

from mc.accounts.tests.helpers import bearer
from mc.interests.tests.helpers import accept, member, pair, send
from mc.messaging.tests.helpers import history, matched, say
from mc.messaging.tests.test_messages import age_match, ready_chat_media
from mc.verification.tests.helpers import J

pytestmark = pytest.mark.django_db


def listing(who, **params):
    qs = "&".join(f"{k}={v}" for k, v in params.items())
    r = who[0].get(f"/api/v1/matches?{qs}", **bearer(who[1]))
    assert r.status_code == 200
    return r.json()


def item(who, mid):
    return next(i for i in listing(who)["items"] if i["id"] == mid)


def test_a_fresh_match_has_no_chat_activity():
    m, f, mid = matched()
    for who in (m, f):
        i = item(who, mid)
        assert i["last_message_at"] is None and i["unread_count"] == 0
        assert i["last_message_kind"] is None and i["last_message_sender"] is None


def test_unread_and_last_message_are_per_viewer_and_never_include_the_text():
    m, f, mid = matched()
    secret = "my number is totally private"
    age_match()
    say(m, mid, "first hello")
    last = say(m, mid, secret)
    assert last.status_code == 201
    mine, theirs = item(m, mid), item(f, mid)
    assert mine["unread_count"] == 0 and mine["last_message_sender"] == "me"
    assert theirs["unread_count"] == 2 and theirs["last_message_sender"] == "them"
    assert (
        theirs["last_message_kind"] == "text"
        and theirs["last_message_at"] == last.json()["created_at"]
    )
    raw = f[0].get("/api/v1/matches", **bearer(f[1])).content.decode()
    assert secret not in raw and "first hello" not in raw and "body" not in raw


def test_reading_clears_unread_and_replying_changes_the_sender():
    m, f, mid = matched()
    say(m, mid, "one")
    newest = say(m, mid, "two").json()["id"]
    assert item(f, mid)["unread_count"] == 2
    f[0].post(f"/api/v1/matches/{mid}/read", {"up_to_message_id": newest}, **bearer(f[1]), **J)
    assert item(f, mid)["unread_count"] == 0
    say(f, mid, "reply")
    assert item(m, mid)["last_message_sender"] == "them" and item(m, mid)["unread_count"] == 1
    assert item(f, mid)["last_message_sender"] == "me"


def test_media_kinds_are_reported_as_a_kind_only():
    m, f, mid = matched()
    age_match()
    note = ready_chat_media(m[2], purpose="voice_note")
    assert say(m, mid, kind="voice", media_id=str(note.id)).status_code == 201
    i = item(f, mid)
    assert i["last_message_kind"] == "voice" and i["unread_count"] == 1
    assert "url" not in str(i["last_message_kind"])


def test_system_messages_are_not_activity():
    from mc.messaging.models import Message

    m, f, mid = matched()
    Message.objects.create(match_id=mid, kind="system", body="system note")
    assert item(m, mid)["last_message_at"] is None and item(m, mid)["unread_count"] == 0
    say(m, mid, "real one")
    assert item(f, mid)["unread_count"] == 1


def test_summaries_do_not_mix_between_matches_or_members():
    a = member("male", age=31)
    f1, f2 = member("female", age=27), member("female", age=29)
    ids = []
    for f in (f1, f2):
        iid = send(a[0], a[1], f[3]).json()["id"]
        ids.append(accept(f[0], f[1], iid).json()["match_id"])
    say(f1, ids[0], "from f1 a")
    say(f1, ids[0], "from f1 b")
    say(f2, ids[1], "from f2")
    by = {i["id"]: i for i in listing(a)["items"]}
    assert by[ids[0]]["unread_count"] == 2 and by[ids[1]]["unread_count"] == 1
    # each woman sees only her own match, with nothing unread
    assert [i["unread_count"] for i in listing(f1)["items"]] == [0]
    assert [i["unread_count"] for i in listing(f2)["items"]] == [0]


def test_blocked_matches_disappear_with_their_stats():
    m, f, mid = matched()
    say(m, mid, "hello")
    assert item(f, mid)["unread_count"] == 1
    r = f[0].post("/api/v1/blocks", {"profile_id": m[3]}, **bearer(f[1]), **J)
    assert r.status_code in (200, 201, 204)
    assert listing(f)["items"] == [] and listing(m)["items"] == []


def test_pagination_keeps_summaries_and_query_count_does_not_grow_with_matches():
    a = member("male", age=33)
    for n in range(3):
        f = member("female", age=26 + n)
        iid = send(a[0], a[1], f[3]).json()["id"]
        mid = accept(f[0], f[1], iid).json()["match_id"]
        say(f, mid, f"hi {n}")
    page1 = listing(a, limit=2)
    assert len(page1["items"]) == 2 and page1["next_cursor"]
    assert all(i["unread_count"] == 1 for i in page1["items"])
    page2 = listing(a, limit=2, cursor=page1["next_cursor"])
    assert len(page2["items"]) == 1 and page2["items"][0]["unread_count"] == 1

    from mc.matches.models import Match
    from mc.messaging import selectors

    match_ids = list(Match.objects.values_list("id", flat=True))
    for subset in (match_ids[:1], match_ids):
        with CaptureQueriesContext(connection) as ctx:
            out = selectors.conversation_summaries(subset, a[2].id)
        assert len(ctx) == 2 and set(out) == set(subset)  # two queries however many matches
    assert selectors.conversation_summaries([], a[2].id) == {}


def test_unmatched_and_history_helpers_still_work_alongside():
    m, f, mid = matched()
    say(m, mid, "x")
    assert history(f, mid).status_code == 200
    m[0].post(f"/api/v1/matches/{mid}/unmatch", **bearer(m[1]), **J)
    assert listing(f)["items"] == []


def test_forbidden_without_auth():
    from django.test import Client

    assert Client(headers={"host": "api.mc.test"}).get("/api/v1/matches").status_code == 401
    _ = pair

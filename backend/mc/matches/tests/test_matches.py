from datetime import timedelta

import pytest
from django.utils import timezone

from devtools.factories import create_member
from mc.accounts.tests.helpers import bearer
from mc.common import events
from mc.discovery import services as discovery
from mc.interests.tests.helpers import accept, member, pair, send
from mc.matches import selectors, services
from mc.matches.events import MatchEnded
from mc.matches.models import Match

pytestmark = pytest.mark.django_db


def matched():
    m, f = pair()
    iid = send(m[0], m[1], f[3]).json()["id"]
    mid = accept(f[0], f[1], iid).json()["match_id"]
    return m, f, mid


def test_list_matches_for_both_members():
    m, f, mid = matched()
    for who, other in ((m, f), (f, m)):
        body = who[0].get("/api/v1/matches", **bearer(who[1])).json()
        assert [i["id"] for i in body["items"]] == [mid]
        assert body["items"][0]["member"]["id"] == other[3]  # public profile id
        assert body["items"][0]["member"]["primary_photo"][
            "url"
        ]  # matched members see each other's photos
        assert str(other[2].id) not in str(body)


def test_list_requires_auth_capability_and_hides_blocked():
    from django.test import Client

    assert Client(headers={"host": "api.mc.test"}).get("/api/v1/matches").status_code == 401
    m, f, mid = matched()
    from mc.safety.models import Block

    Block.objects.create(blocker=m[2], blocked=f[2])
    assert m[0].get("/api/v1/matches", **bearer(m[1])).json()["items"] == []
    from mc.verification.tests.helpers import new_user

    c, r = new_user("+256772777777")
    assert c.get("/api/v1/matches", **bearer(r)).status_code == 403


def test_lapsed_member_still_sees_matches():
    m, f, mid = matched()
    from mc.entitlements.models import Entitlement

    Entitlement.objects.all().delete()  # trial/membership gone → read-only world
    assert len(f[0].get("/api/v1/matches", **bearer(f[1])).json()["items"]) == 1


def test_unmatch_by_either_member_is_idempotent_and_hides_for_both(
    django_capture_on_commit_callbacks,
):
    got = []
    events.subscribe(MatchEnded)(got.append)
    m, f, mid = matched()
    with django_capture_on_commit_callbacks(execute=True):
        assert m[0].post(f"/api/v1/matches/{mid}/unmatch", **bearer(m[1])).status_code == 204
        assert m[0].post(f"/api/v1/matches/{mid}/unmatch", **bearer(m[1])).status_code == 204
    match = Match.objects.get()
    assert match.status == "unmatched" and match.ended_by_id == m[2].id and match.ended_at
    assert len(got) == 1 and got[0].reason == "unmatched"
    for who in (m, f):
        assert who[0].get("/api/v1/matches", **bearer(who[1])).json()["items"] == []


def test_non_member_cannot_unmatch():
    m, f, mid = matched()
    stranger = member("female")
    assert (
        stranger[0].post(f"/api/v1/matches/{mid}/unmatch", **bearer(stranger[1])).status_code == 404
    )
    assert Match.objects.get().status == "active"


def test_matched_and_recently_unmatched_are_out_of_discovery_and_cannot_be_re_interested():
    m, f, mid = matched()
    assert str(f[2].id) not in {e.account_id for e in discovery.build_ranked_pool(m[2])[0]}
    assert send(m[0], m[1], f[3]).json()["code"] == "not_eligible"  # already matched
    services.unmatch(match_id=mid, by=m[2].id)
    assert str(f[2].id) not in {e.account_id for e in discovery.build_ranked_pool(m[2])[0]}
    assert send(m[0], m[1], f[3]).json()["code"] == "not_eligible"  # cool-off after unmatch
    Match.objects.update(ended_at=timezone.now() - timedelta(days=91))
    assert send(m[0], m[1], f[3]).status_code == 201


def test_first_two_way_message_set_only_when_both_have_sent():
    m, f, mid = matched()
    t1, t2, t3 = (timezone.now() + timedelta(minutes=i) for i in (1, 2, 3))
    match = services.record_participant_message(match_id=mid, sender_id=m[2].id, at=t1)
    assert match.first_two_way_message_at is None
    match = services.record_participant_message(match_id=mid, sender_id=m[2].id, at=t2)
    assert match.first_two_way_message_at is None  # same sender again: still one-way
    match = services.record_participant_message(match_id=mid, sender_id=f[2].id, at=t3)
    assert match.first_two_way_message_at == t3
    match = services.record_participant_message(
        match_id=mid, sender_id=m[2].id, at=t3 + timedelta(hours=1)
    )
    assert match.first_two_way_message_at == t3  # never reset


def test_one_active_match_per_pair_even_when_created_twice():
    m, f, mid = matched()
    again, created = services.create_match(account_x=f[2].id, account_y=m[2].id)
    assert not created and str(again.id) == mid and Match.objects.count() == 1
    assert selectors.counterpart_ids(m[2].id) == {f[2].id}
    _ = create_member

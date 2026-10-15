from datetime import timedelta

import pytest
from django.utils import timezone

from mc.accounts.tests.helpers import bearer
from mc.entitlements import services as ent
from mc.interests import selectors, services
from mc.interests.models import Interest
from mc.matches.models import Match
from mc.safety.models import Block
from mc.verification.tests.helpers import J

from .helpers import accept, member, send

pytestmark = pytest.mark.django_db


def sent_pair(trial_recipient=False):
    m = member("male", age=30)
    f = member("female", age=28, trial=trial_recipient)
    resp = send(m[0], m[1], f[3])
    return m, f, resp.json()["id"]


def test_accept_creates_exactly_one_active_match_and_is_idempotent():
    m, f, iid = sent_pair()
    r1 = accept(f[0], f[1], iid)
    r2 = accept(f[0], f[1], iid)  # fresh key, same user action repeated
    assert r1.status_code == r2.status_code == 200
    assert r1.json()["match_id"] == r2.json()["match_id"]
    assert Match.objects.filter(status="active").count() == 1
    assert Interest.objects.get().status == "accepted" and Interest.objects.get().responded_at


def test_non_member_can_accept_by_default_but_flag_can_disable(settings):
    m, f, iid = sent_pair(trial_recipient=False)  # recipient has no trial/membership
    settings.NONMEMBER_CAN_ACCEPT_INTEREST = False
    resp = accept(f[0], f[1], iid)
    assert resp.status_code == 403 and resp.json()["capability"] == "accept_interest"
    settings.NONMEMBER_CAN_ACCEPT_INTEREST = True
    assert accept(f[0], f[1], iid).status_code == 200


def test_only_the_recipient_can_accept_or_pass_and_ids_dont_leak():
    m, f, iid = sent_pair()
    assert accept(m[0], m[1], iid).status_code == 404  # the sender
    stranger = member("female")
    assert accept(stranger[0], stranger[1], iid).status_code == 404
    assert (
        stranger[0].post(f"/api/v1/interests/{iid}/pass", **bearer(stranger[1])).status_code == 404
    )
    import uuid

    assert accept(f[0], f[1], str(uuid.uuid4())).status_code == 404


def test_accept_after_pass_or_expiry_conflicts():
    m, f, iid = sent_pair()
    assert f[0].post(f"/api/v1/interests/{iid}/pass", **bearer(f[1])).status_code == 204
    resp = accept(f[0], f[1], iid)
    assert resp.status_code == 409 and not Match.objects.exists()
    m2, f2, iid2 = sent_pair()
    Interest.objects.filter(id=iid2).update(expires_at=timezone.now() - timedelta(minutes=1))
    resp = accept(f2[0], f2[1], iid2)
    assert resp.status_code == 409
    assert Interest.objects.get(id=iid2).status == "expired"


def test_accept_blocked_pair_is_404_and_no_match():
    m, f, iid = sent_pair()
    Block.objects.create(blocker=m[2], blocked=f[2])
    assert accept(f[0], f[1], iid).status_code == 404 and not Match.objects.exists()


def test_pass_sender_never_sees_passed():
    m, f, iid = sent_pair()
    assert f[0].post(f"/api/v1/interests/{iid}/pass", **bearer(f[1])).status_code == 204
    assert (
        f[0].post(f"/api/v1/interests/{iid}/pass", **bearer(f[1])).status_code == 204
    )  # idempotent
    sent = m[0].get("/api/v1/interests/sent", **bearer(m[1])).json()["items"]
    assert [i["status"] for i in sent] == ["pending"]
    assert "pass" not in str(sent).lower()
    Interest.objects.update(expires_at=timezone.now() - timedelta(seconds=1))
    sent = m[0].get("/api/v1/interests/sent", **bearer(m[1])).json()["items"]
    assert [i["status"] for i in sent] == ["expired"]
    assert f[0].get("/api/v1/interests/received", **bearer(f[1])).json()["items"] == []


def test_expire_job_is_idempotent_and_only_touches_due_pending():
    m, f, iid = sent_pair()
    m2, f2, iid2 = sent_pair()
    Interest.objects.filter(id=iid).update(expires_at=timezone.now() - timedelta(days=1))
    assert services.expire_interests() == 1
    assert services.expire_interests() == 0
    assert (
        Interest.objects.get(id=iid).status == "expired"
        and Interest.objects.get(id=iid2).status == "pending"
    )
    from mc.interests import tasks

    assert tasks.expire_interests() == 0


def test_expire_job_batches(settings):
    settings.INTEREST_EXPIRY_BATCH = 2
    for _ in range(5):
        sent_pair()
    Interest.objects.update(expires_at=timezone.now() - timedelta(minutes=1))
    assert services.expire_interests() == 5


# ---- lists ---------------------------------------------------------------------------------------
def test_received_list_shape_and_photo_grant():
    m, f, iid = sent_pair(trial_recipient=False)
    resp = f[0].get("/api/v1/interests/received", **bearer(f[1]))
    assert resp.status_code == 200
    item = resp.json()["items"][0]
    assert item["id"] == iid and item["status"] == "pending"
    assert item["sender"]["id"] == m[3]  # public profile id, never the account id
    assert str(m[2].id) not in resp.content.decode()
    assert item["sender"]["verified"] == {"age": True, "identity": True, "photos": True}
    assert item["sender"]["primary_photo"]["url"]  # recipient is granted the sender's photo
    assert item["snapshot"]["text"].startswith("I am a kind and hardworking")
    assert item["sender"]["marital_status_label"] is None
    for key in ("expires_at", "created_at"):
        assert item[key]
    # an unrelated member cannot fetch that photo
    from mc.media import selectors as media_selectors
    from mc.profiles.models import Photo

    photo = Photo.objects.filter(profile__account=m[2]).first()
    stranger = member("female")
    assert media_selectors.signed_url(photo.media, stranger[2]) is None
    assert media_selectors.signed_url(photo.media, f[2]) is not None


def test_photo_grant_ends_when_interest_is_passed():
    from mc.media import selectors as media_selectors
    from mc.profiles.models import Photo

    m, f, iid = sent_pair()
    photo = Photo.objects.filter(profile__account=m[2]).first()
    Photo.objects.filter(profile__account=f[2]).update()  # noqa: no-op to keep ORM usage explicit
    from mc.profiles.models import Profile

    Profile.objects.filter(account=m[2]).update(status="draft")  # sender not browsable by others
    assert media_selectors.signed_url(photo.media, f[2]) is not None  # grant via pending interest
    services.pass_interest(recipient=f[2], interest_id=iid)
    assert media_selectors.signed_url(photo.media, f[2]) is None


def test_received_available_to_non_members_but_not_unverified():
    m, f, iid = sent_pair(trial_recipient=False)
    assert f[0].get("/api/v1/interests/received", **bearer(f[1])).status_code == 200
    from mc.verification.tests.helpers import new_user

    c, r = new_user("+256772999999")
    resp = c.get("/api/v1/interests/received", **bearer(r))
    assert resp.status_code == 403 and resp.json()["capability"] == "receive_interest"


def test_lists_hide_blocked_users_and_paginate():
    f = member("female")
    senders = [member("male") for _ in range(5)]
    for s in senders:
        assert send(s[0], s[1], f[3]).status_code == 201
    Block.objects.create(blocker=f[2], blocked=senders[0][2])
    page1 = f[0].get("/api/v1/interests/received?limit=2", **bearer(f[1])).json()
    page2 = (
        f[0]
        .get(f"/api/v1/interests/received?limit=2&cursor={page1['next_cursor']}", **bearer(f[1]))
        .json()
    )
    page3 = (
        f[0]
        .get(f"/api/v1/interests/received?limit=2&cursor={page2['next_cursor']}", **bearer(f[1]))
        .json()
    )
    ids = [i["sender"]["id"] for p in (page1, page2, page3) for i in p["items"]]
    assert (
        len(ids) == len(set(ids)) == 4 and senders[0][3] not in ids and page3["next_cursor"] is None
    )
    assert f[0].get("/api/v1/interests/received?limit=0", **bearer(f[1])).status_code == 422


def test_lists_require_auth():
    from django.test import Client

    c = Client(headers={"host": "api.mc.test"})
    assert c.get("/api/v1/interests/received").status_code == 401
    assert c.get("/api/v1/interests/sent").status_code == 401


def test_cancel_between_deletes_snapshots():
    m, f, iid = sent_pair()
    assert services.cancel_between(a=m[2].id, b=f[2].id) == 1
    assert Interest.objects.get().status == "cancelled" and Interest.objects.get().snapshot is None
    from mc.interests.models import InterestSnapshot

    assert not InterestSnapshot.objects.exists()
    assert selectors.sender_visible_status(Interest.objects.get()) == "expired"
    _ = (ent, J)

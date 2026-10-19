from datetime import timedelta

import pytest
from django.utils import timezone
from freezegun import freeze_time

from devtools.factories import create_member, default_answer_values
from mc.accounts.tests.helpers import bearer
from mc.interests.models import Interest, InterestSnapshot
from mc.matches.models import Match
from mc.profiles.models import Description, Profile
from mc.safety.models import Block

from .helpers import J, member, pair, send

pytestmark = pytest.mark.django_db


def test_requires_auth_and_idempotency_key():
    from django.test import Client

    c = Client(headers={"host": "api.mc.test"})
    assert c.post("/api/v1/interests", {}, **J).status_code == 401
    m, f = pair()
    assert (
        m[0].post("/api/v1/interests", {"recipient_id": f[3]}, **bearer(m[1]), **J).status_code
        == 422
    )


def test_send_creates_pending_interest_with_snapshot():
    (mc, mr, ma, _), (_, _, fa, fpid) = pair()
    resp = send(mc, mr, fpid)
    assert resp.status_code == 201
    body = resp.json()
    assert (
        body["status"] == "pending"
        and body["recipient_id"] == fpid
        and body["remaining_today"] == 19
    )
    assert body["expires_at"] > body["created_at"]
    i = Interest.objects.get()
    assert (i.sender, i.recipient, i.status) == (ma, fa, "pending")
    assert i.snapshot.text == Profile.objects.get(account=ma).current_description.text
    assert i.snapshot.display_name == Profile.objects.get(account=ma).display_name
    assert abs((i.expires_at - i.created_at) - timedelta(days=30)) < timedelta(seconds=5)


def test_snapshot_is_a_frozen_copy():
    (mc, mr, ma, _), (_, _, _, fpid) = pair()
    send(mc, mr, fpid)
    prof = Profile.objects.get(account=ma)
    new = Description.objects.create(
        profile=prof, version=2, text="Completely different text now. " * 6, status="approved"
    )
    Profile.objects.filter(pk=prof.pk).update(current_description=new, display_name="Changed")
    snap = InterestSnapshot.objects.get()
    assert snap.text != new.text and snap.display_name != "Changed"


def test_idempotent_retry_returns_same_body_and_one_row():
    (mc, mr, _, _), (_, _, _, fpid) = pair()
    a = send(mc, mr, fpid, key="interest-key-1")
    b = send(mc, mr, fpid, key="interest-key-1")
    assert a.status_code == b.status_code == 201 and a.json() == b.json()
    assert Interest.objects.count() == 1


def test_duplicate_pending_with_new_key_is_409_with_existing_id():
    (mc, mr, _, _), (_, _, _, fpid) = pair()
    first = send(mc, mr, fpid).json()
    resp = send(mc, mr, fpid)
    assert resp.status_code == 409 and resp.json()["code"] == "duplicate"
    assert resp.json()["interest_id"] == first["id"] and Interest.objects.count() == 1


def test_unverified_sender_is_asked_to_verify():
    """v2: an unverified member can browse but can't affect anyone else (send_interest needs verification)."""
    m = member("male", trial=False, verified=False, live=False)
    f = member("female")
    resp = send(m[0], m[1], f[3])
    assert resp.status_code == 403
    assert resp.json()["code"] == "verification_required"
    assert resp.json()["capability"] == "send_interest"
    assert Interest.objects.count() == 0


def test_sender_needs_live_profile_and_approved_description():
    m, f = pair()
    Profile.objects.filter(account=m[2]).update(status="draft")
    assert send(m[0], m[1], f[3]).json()["code"] == "profile_incomplete"
    Profile.objects.filter(account=m[2]).update(status="live", current_description=None)
    resp = send(m[0], m[1], f[3])
    assert resp.status_code == 422 and resp.json()["code"] == "description_rejected"


@pytest.mark.parametrize(
    "why",
    [
        "self",
        "unknown",
        "recipient_draft",
        "recipient_suspended",
        "same_gender",
        "blocked_by_me",
        "blocked_me",
        "age_filter",
        "married_filter",
    ],
)
def test_not_eligible_cases_are_indistinguishable(why):
    m, f = pair()
    target = f[3]
    if why == "self":
        target = m[3]
    elif why == "unknown":
        import uuid

        target = str(uuid.uuid4())
    elif why == "recipient_draft":
        Profile.objects.filter(account=f[2]).update(status="draft")
    elif why == "recipient_suspended":
        f[2].status = "suspended"
        f[2].save()
    elif why == "same_gender":
        other = member("male")
        target = other[3]
    elif why == "blocked_by_me":
        Block.objects.create(blocker=m[2], blocked=f[2])
    elif why == "blocked_me":
        Block.objects.create(blocker=f[2], blocked=m[2])
    elif why == "age_filter":
        from mc.profiles.models import Preference

        Preference.objects.filter(profile__account=f[2]).update(age_min=18, age_max=25)
    elif why == "married_filter":
        Profile.objects.filter(account=f[2]).update(
            marital_status="married_customary", show_married_profiles=False
        )
    resp = send(m[0], m[1], target)
    assert resp.status_code == 403 and resp.json()["code"] == "not_eligible"
    assert (
        resp.json()["detail"] == "You can't send an interest to this profile."
    )  # same words every time
    assert not Interest.objects.exists()


def test_dealbreaker_makes_pair_not_eligible():
    base = default_answer_values()
    m = member(
        "male", answer_values={**base, "children_want": "yes"}, dealbreakers=("children_want",)
    )
    f = member("female", answer_values={**base, "children_want": "no"})
    assert send(m[0], m[1], f[3]).json()["code"] == "not_eligible"


def test_reverse_pending_interest_is_treated_as_accept():
    (mc, mr, ma, mpid), (fc, fr, fa, fpid) = pair()
    first = send(fc, fr, mpid)  # she is interested in him
    assert first.status_code == 201
    resp = send(mc, mr, fpid)  # he now sends → accept path
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "accepted" and body["match_id"]
    assert Interest.objects.count() == 1 and Interest.objects.get().status == "accepted"
    match = Match.objects.get()
    assert match.status == "active" and {match.user_a_id, match.user_b_id} == {ma.id, fa.id}
    assert str(body["id"]) == first.json()["id"]


def test_expired_reverse_pending_does_not_auto_accept():
    (mc, mr, ma, mpid), (fc, fr, fa, fpid) = pair()
    send(fc, fr, mpid)
    Interest.objects.update(expires_at=timezone.now() - timedelta(minutes=1))
    resp = send(mc, mr, fpid)
    assert resp.status_code == 201 and not Match.objects.exists()


def test_daily_limit_trial_and_member_and_reset(settings):
    settings.INTEREST_DAILY_LIMIT_TRIAL = 2
    with freeze_time("2026-10-20 09:00:00+03:00") as t:
        m = member("male", trial=True)
        targets = [member("female") for _ in range(3)]
        assert send(m[0], m[1], targets[0][3]).json()["remaining_today"] == 1
        assert send(m[0], m[1], targets[1][3]).json()["remaining_today"] == 0
        resp = send(m[0], m[1], targets[2][3])
        assert resp.status_code == 429 and resp.json()["code"] == "limit_reached"
        t.move_to(
            "2026-10-21 00:30:00+03:00"
        )  # past Kampala midnight (access token still valid: <15 min? no)
    # next-day behaviour exercised at service level (token expiry aside)
    from mc.interests import services

    with freeze_time("2026-10-21 00:30:00+03:00"):
        from mc.entitlements import services as ent

        ent.grant(
            account=m[2],
            ends_at=timezone.now() + timedelta(days=2),
            reason="test",
            actor_id=m[2].id,
            actor_role="support",
        )
        res = services.send_interest(
            sender=m[2],
            recipient_profile_id=__import__("uuid").UUID(targets[2][3]),
            idempotency_key="next-day-key-1",
        )
        assert res["created"] is True


def test_member_limit_is_higher(settings):
    settings.INTEREST_DAILY_LIMIT_TRIAL = 1
    settings.INTEREST_DAILY_LIMIT_MEMBER = 3
    from mc.entitlements import services as ent

    m = member("male", trial=False)
    ent.grant_from_purchase(
        account=m[2],
        purchase_id=__import__("uuid").uuid4(),
        period_start=timezone.now() - timedelta(hours=1),
        period_end=timezone.now() + timedelta(days=30),
    )
    for _ in range(3):
        assert send(m[0], m[1], member("female")[3]).status_code == 201
    assert send(m[0], m[1], member("female")[3]).status_code == 429


def test_resend_cooldown_after_pass_or_expiry_without_revealing_which():
    (mc, mr, _, _), (_, _, _, fpid) = pair()
    send(mc, mr, fpid)
    for status in ("passed", "expired"):
        Interest.objects.update(status=status)
        resp = send(mc, mr, fpid)
        assert resp.status_code == 403 and resp.json()["code"] == "not_eligible"
        assert (
            "pass" not in resp.content.decode().lower()
            and "declin" not in resp.content.decode().lower()
        )
    Interest.objects.update(created_at=timezone.now() - timedelta(days=91))
    assert send(mc, mr, fpid).status_code == 201


def test_event_published_after_commit(django_capture_on_commit_callbacks):
    from mc.common import events
    from mc.interests.events import InterestSent

    got = []
    events.subscribe(InterestSent)(got.append)
    (mc, mr, ma, _), (_, _, fa, fpid) = pair()
    with django_capture_on_commit_callbacks(execute=True):
        send(mc, mr, fpid)
    assert len(got) == 1 and (got[0].sender_id, got[0].recipient_id) == (ma.id, fa.id)


def test_sending_marks_discovery_impression_action():
    from django.utils import timezone as tz

    from mc.discovery.models import Impression

    (mc, mr, ma, _), (_, _, fa, fpid) = pair()
    Impression.objects.create(
        viewer=ma, candidate=fa, score=0.7, model_version="v1", position=0, shown_at=tz.now()
    )
    send(mc, mr, fpid)
    assert Impression.objects.get().action == "interest"


def test_unrelated_member_data_untouched():
    other = create_member(gender="female", age=28)
    (mc, mr, _, _), (_, _, _, fpid) = pair()
    send(mc, mr, fpid)
    assert Interest.objects.filter(recipient=other).count() == 0

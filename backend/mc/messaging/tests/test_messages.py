import uuid
from datetime import timedelta

import pytest
from django.utils import timezone

from mc.accounts.tests.helpers import bearer
from mc.matches.models import Match
from mc.media.models import MediaObject
from mc.messaging import selectors, services
from mc.messaging.models import Message
from mc.verification.tests.helpers import J

from .helpers import history, matched, member, say

pytestmark = pytest.mark.django_db


def age_match(minutes_ago_hours=100):
    """Move the match out of the contact-block window."""
    Match.objects.update(created_at=timezone.now() - timedelta(hours=minutes_ago_hours))


def ready_chat_media(owner, purpose="chat_image", moderation="approved"):
    mid = uuid.uuid4()
    return MediaObject.objects.create(
        id=mid, owner=owner, purpose=purpose, declared_mime="image/jpeg", declared_bytes=10,
        upload_key=f"uploads/{mid}", storage_key=f"media/{mid}.webp", mime="image/webp", bytes=9,
        width=100, height=100, duration_ms=2000 if purpose == "voice_note" else None, status="ready", moderation=moderation,
    )  # fmt: skip


def test_send_and_receive_text():
    m, f, mid = matched()
    resp = say(m, mid, "Good evening")
    assert resp.status_code == 201
    body = resp.json()
    assert body["sender"] == "me" and body["kind"] == "text" and body["body"] == "Good evening"
    assert body["safety_tip"] is False
    theirs = history(f, mid).json()["items"][0]
    assert (
        theirs["sender"] == "them"
        and theirs["body"] == "Good evening"
        and theirs["client_msg_id"] is None
    )


def test_scenario_04_retry_after_timeout_creates_one_row():
    m, f, mid = matched()
    cid = str(uuid.uuid4())
    a, b, c = say(m, mid, "x", cid), say(m, mid, "x", cid), say(m, mid, "x", cid)
    assert (a.status_code, b.status_code, c.status_code) == (201, 200, 200)
    assert a.json()["id"] == b.json()["id"] == c.json()["id"]
    assert Message.objects.filter(kind="text").count() == 1
    other = say(f, mid, "reply", cid)  # same client id from the OTHER member is a different message
    assert other.status_code == 201 and Message.objects.filter(kind="text").count() == 2


def test_client_msg_id_cannot_cross_conversations():
    m, f, mid = matched()
    cid = str(uuid.uuid4())
    say(m, mid, "hi", cid)
    f2 = member("female")
    from mc.interests.tests.helpers import accept, send

    iid = send(m[0], m[1], f2[3]).json()["id"]
    mid2 = accept(f2[0], f2[1], iid).json()["match_id"]
    assert say(m, mid2, "hi", cid).status_code == 409


@pytest.mark.parametrize("bad", ["", "   ", "x" * 2001])
def test_text_validation(bad):
    m, f, mid = matched()
    assert say(m, mid, bad).status_code == 422
    assert not Message.objects.filter(kind="text").exists()


def test_membership_and_auth_enforced():
    from django.test import Client

    m, f, mid = matched()
    stranger = member("female")
    assert say(stranger, mid).status_code == 404
    assert history(stranger, mid).status_code == 404
    assert (
        Client(headers={"host": "api.mc.test"}).get(f"/api/v1/matches/{mid}/messages").status_code
        == 401
    )
    assert say(m, str(uuid.uuid4())).status_code == 404


def test_chat_in_a_match_stays_free_after_the_trial_lapses():
    """v2 (ADR-0009): a verified member keeps chatting inside a match without a trial or membership."""
    m, f, mid = matched()
    say(m, mid, "before expiry")
    from mc.entitlements.models import Entitlement

    Entitlement.objects.filter(account=f[2]).delete()  # her trial lapses
    assert say(f, mid, "can I reply?").status_code == 201
    texts = [i["body"] for i in history(f, mid).json()["items"] if i["kind"] == "text"]
    assert sorted(texts) == ["before expiry", "can I reply?"]


def test_send_requires_capability_when_free_chat_is_switched_off(settings):
    settings.FREE_CHAT_IN_MATCH = False
    m, f, mid = matched()
    say(m, mid, "before expiry")
    from mc.entitlements.models import Entitlement

    Entitlement.objects.filter(account=f[2]).delete()  # her trial lapses
    resp = say(f, mid, "can I reply?")
    assert resp.status_code == 403 and resp.json()["capability"] == "send_message"
    assert resp.json()["code"] == "entitlement_required"
    assert [i["body"] for i in history(f, mid).json()["items"] if i["kind"] == "text"] == [
        "before expiry"
    ]  # read-only, no data loss


def test_unmatched_and_blocked_conversations_are_gone_for_both():
    from mc.matches import services as match_services
    from mc.safety.models import Block

    m, f, mid = matched()
    say(m, mid, "hi")
    match_services.unmatch(match_id=mid, by=f[2].id)
    for who in (m, f):
        assert history(who, mid).status_code == 404 and say(who, mid).status_code == 404
    m2, f2, mid2 = matched()
    Block.objects.create(blocker=m2[2], blocked=f2[2])
    assert say(f2, mid2).status_code == 404 and history(m2, mid2).status_code == 404


def test_contact_details_blocked_for_first_72_hours_only():
    m, f, mid = matched()
    resp = say(m, mid, "call me on 0772123456")
    assert resp.status_code == 422 and resp.json()["code"] == "contact_details_blocked"
    assert resp.json()["reason"] == "phone_number" and "first 3 days" in resp.json()["detail"]
    assert not Message.objects.filter(kind="text").exists()
    assert say(m, mid, "see https://example.com/me").status_code == 422
    assert say(m, mid, "add me on whatsapp").status_code == 422
    assert say(m, mid, "I love Sunday lunches").status_code == 201
    age_match(73)
    assert say(m, mid, "my number is 0772123456").status_code == 201


def test_scam_heuristics_flag_but_never_block_and_sender_isnt_told():
    m, f, mid = matched()
    age_match()
    resp = say(m, mid, "please send me money for the hospital bill")
    assert resp.status_code == 201 and resp.json()["safety_tip"] is False  # sender sees no flag
    theirs = history(f, mid).json()["items"][0]
    assert theirs["safety_tip"] is True and theirs["body"].startswith("please send me money")
    assert Message.objects.get(kind="text").moderation_flag == "financial_request"
    assert "moderation_flag" not in str(theirs)


def test_photo_unlock_rule(settings):
    settings.PHOTO_UNLOCK_MIN_MESSAGES = 3
    m, f, mid = matched()
    media = ready_chat_media(m[2])
    resp = say(m, mid, kind="image", media_id=str(media.id))
    assert (
        resp.status_code == 403
        and resp.json()["code"] == "photo_locked"
        and resp.json()["needed"] == 3
    )
    for i in range(3):
        say(m, mid, f"m{i}")
        say(f, mid, f"f{i}")
    resp = say(m, mid, kind="image", media_id=str(media.id))
    assert resp.status_code == 201
    msg = resp.json()
    assert msg["kind"] == "image" and msg["media"]["url"] and msg["body"] is None
    # recipient gets a signed URL; an outsider does not
    from mc.media import selectors as media_selectors

    assert selectors.message_payload(Message.objects.get(kind="image"), f[2])["media"]["url"]
    outsider = member("female")
    assert media_selectors.signed_url(media, outsider[2]) is None


def test_media_rules():
    m, f, mid = matched()
    age_match()
    for other in (
        ready_chat_media(f[2]),
        ready_chat_media(m[2], purpose="voice_note"),
        ready_chat_media(m[2], moderation="review"),
    ):
        assert say(m, mid, kind="image", media_id=str(other.id)).status_code in (403, 422)
    assert say(m, mid, kind="image").status_code == 422  # missing media
    assert say(m, mid, "text with media", media_id=str(uuid.uuid4())).status_code == 422


def test_voice_note_and_double_send_of_same_media():
    m, f, mid = matched()
    note = ready_chat_media(m[2], purpose="voice_note")
    resp = say(m, mid, kind="voice", media_id=str(note.id))
    assert resp.status_code == 201 and resp.json()["media"]["duration_ms"] == 2000
    assert say(m, mid, kind="voice", media_id=str(note.id)).status_code == 409


def test_history_pagination_newest_first_and_before_cursor():
    m, f, mid = matched()
    for i in range(7):
        say(m, mid, f"msg {i}")
    p1 = history(f, mid, limit=3).json()
    p2 = history(f, mid, limit=3, before=p1["next_cursor"]).json()
    p3 = history(f, mid, limit=3, before=p2["next_cursor"]).json()
    bodies = [i["body"] for p in (p1, p2, p3) for i in p["items"] if i["kind"] == "text"]
    assert bodies == [f"msg {i}" for i in range(6, -1, -1)]
    assert history(f, mid, before="garbage").status_code == 422


def test_system_message_on_match_created(django_capture_on_commit_callbacks):
    from mc.interests.tests.helpers import accept, pair, send

    mm, ff = pair()
    iid = send(mm[0], mm[1], ff[3]).json()["id"]
    with django_capture_on_commit_callbacks(execute=True):
        mid = accept(ff[0], ff[1], iid).json()["match_id"]
    items = history(mm, mid).json()["items"]
    assert [(i["kind"], i["sender"], i["body"]) for i in items] == [
        ("system", "system", "match_created")
    ]


def test_read_receipts():
    from mc.common import events
    from mc.messaging.events import MessageRead

    m, f, mid = matched()
    first, second = say(m, mid, "one").json(), say(m, mid, "two").json()
    got = []
    events.subscribe(MessageRead)(got.append)
    assert (
        f[0]
        .post(f"/api/v1/matches/{mid}/read", {"up_to_message_id": first["id"]}, **bearer(f[1]), **J)
        .status_code
        == 204
    )
    assert (
        Message.objects.get(id=first["id"]).read_at
        and not Message.objects.get(id=second["id"]).read_at
    )
    assert (
        services.mark_read(
            account=f[2], match_id=uuid.UUID(mid), up_to_message_id=uuid.UUID(first["id"])
        )
        == 0
    )  # idempotent
    # a sender can't mark their own messages read; strangers/unknown ids get 404
    assert (
        m[0]
        .post(
            f"/api/v1/matches/{mid}/read", {"up_to_message_id": second["id"]}, **bearer(m[1]), **J
        )
        .status_code
        == 204
    )
    assert not Message.objects.get(id=second["id"]).read_at
    assert (
        f[0]
        .post(
            f"/api/v1/matches/{mid}/read",
            {"up_to_message_id": str(uuid.uuid4())},
            **bearer(f[1]),
            **J,
        )
        .status_code
        == 404
    )


def test_first_two_way_message_recorded_through_service():
    m, f, mid = matched()
    say(m, mid, "hi")
    assert Match.objects.get().first_two_way_message_at is None
    say(f, mid, "hello")
    assert Match.objects.get().first_two_way_message_at is not None


def test_rate_limit(settings):
    settings.MESSAGES_PER_MINUTE = 3
    m, f, mid = matched()
    codes = [say(m, mid, f"m{i}").status_code for i in range(5)]
    assert codes == [201, 201, 201, 429, 429]
    _ = J

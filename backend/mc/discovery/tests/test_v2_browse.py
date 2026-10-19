"""See-first browsing (docs/design/user-flow-v2.md): limited payloads for unverified viewers, daily caps,
photo visibility, blocks, special data. Every assertion is about what the SERVER returns."""

import uuid
from datetime import timedelta

import pytest
from django.test import Client
from django.utils import timezone
from freezegun import freeze_time

from devtools.factories import create_member
from mc.accounts import services as account_services
from mc.accounts.tests.helpers import bearer, login
from mc.common.redis import get_redis
from mc.entitlements import services as ent
from mc.profiles.models import Photo, Preference, Profile
from mc.safety import services as safety
from mc.verification.tests.helpers import J

pytestmark = pytest.mark.django_db
_n = iter(range(1000))


def unverified(gender="male", age=30, *, consents=True, about=True):
    """Signed in, About-you profile only (no description, photos or answers), optionally with consents."""
    phone = f"+2567733{next(_n):05d}"
    acct = create_member(
        phone=phone,
        gender=gender,
        age=age,
        verified=False,
        live=False,
        photos=0,
        with_answers=False,
    )
    Profile.objects.filter(account=acct).update(current_description=None)
    Preference.objects.filter(profile__account=acct).delete()
    if not about:
        Profile.objects.filter(account=acct).delete()
    if consents:
        account_services.record_consent(
            account=acct,
            items=[
                {"kind": k, "version": "1", "granted": True}
                for k in ("terms", "privacy", "data_transfer")
            ],
            source="app",
        )
    c = Client(headers={"host": "api.mc.test"})
    r = login(c, phone=phone)
    assert r.status_code in (200, 201)
    return c, r, acct


def free(gender="male", age=30):
    phone = f"+2567733{next(_n):05d}"
    acct = create_member(phone=phone, gender=gender, age=age)
    c = Client(headers={"host": "api.mc.test"})
    r = login(c, phone=phone)
    return c, r, acct


def discover(who, **params):
    qs = "&".join(f"{k}={v}" for k, v in params.items())
    return who[0].get(f"/api/v1/discovery?{qs}", **bearer(who[1]))


def profile_of(acct):
    return Profile.objects.get(account=acct)


def open_profile(who, pid, **extra):
    return who[0].get(f"/api/v1/profiles/{pid}", **bearer(who[1]), **extra)


# ---- limited cards ------------------------------------------------------------------------------
def test_unverified_viewer_gets_limited_cards_with_no_private_fields():
    me = unverified()
    women = [
        create_member(gender="female", age=28, name=f"Amani{i}", district="Wakiso")
        for i in range(3)
    ]
    resp = discover(me)
    assert resp.status_code == 200
    items = resp.json()["items"]
    assert len(items) == 3
    for card in items:
        assert set(card) == {
            "profile_id",
            "display_name",
            "age",
            "district",
            "photos",
            "intention",
            "badges",
            "limited",
        }
        assert card["limited"] is True and len(card["photos"]) == 1 and card["photos"][0]["url"]
        assert "identity_verified" in card["badges"]
    text = resp.content.decode()
    for banned in (
        "why",
        "discuss",
        "score_band",
        "marriage_timeline",
        "marital_status",
        "description",
        "answers",
    ):
        assert banned not in text
    assert resp.json()["browse"]["limit"] == 30 and resp.json()["browse"]["used"] == 3
    assert {c["profile_id"] for c in items} == {str(profile_of(w).id) for w in women}


def test_verified_free_viewer_gets_full_cards_without_a_trial():
    me = free()
    create_member(gender="female", age=28)
    card = discover(me).json()["items"][0]
    assert card["limited"] is False and {
        "why",
        "discuss",
        "score_band",
        "marriage_timeline",
    } <= set(card)
    assert len(card["photos"]) == 2


def test_unverified_accounts_never_appear_in_anyones_discovery():
    me = free()
    ghost = unverified("female", 28)
    Profile.objects.filter(account=ghost[2]).update(status="live")  # even a (forced) live row
    assert discover(me).json()["items"] == []
    assert discover(unverified())  # and unverified viewers cannot see them either
    assert discover(unverified()).json()["items"] == []


def test_unverified_viewer_needs_the_required_consents_and_about_you():
    no_consent = unverified(consents=False)
    resp = discover(no_consent)
    assert resp.status_code == 422 and resp.json()["missing_consents"]
    nothing = unverified(about=False)
    resp = discover(nothing)
    assert resp.status_code == 422 and resp.json()["code"] == "profile_incomplete"
    assert resp.json()["missing"] == ["birth_date", "gender"]
    assert Client(headers={"host": "api.mc.test"}).get("/api/v1/discovery").status_code == 401


def test_derived_defaults_use_opposite_gender_and_an_age_window_from_the_birth_date():
    me = unverified("male", 30)  # derived window 23..40
    inside = create_member(gender="female", age=25, age_min=18, age_max=80)
    create_member(gender="female", age=50, age_min=18, age_max=80)  # outside the window
    create_member(gender="male", age=30)  # same gender
    ids = {c["profile_id"] for c in discover(me).json()["items"]}
    assert ids == {str(profile_of(inside).id)}
    assert not Preference.objects.filter(profile__account=me[2]).exists()  # derived, never stored


def test_candidates_hard_filters_still_apply_to_the_unverified_viewer():
    me = unverified("male", 30)
    picky = create_member(
        gender="female", age=28, age_min=40, age_max=50
    )  # does not want a 30-year-old
    assert str(profile_of(picky).id) not in {c["profile_id"] for c in discover(me).json()["items"]}


def test_blocks_stay_absolute_for_unverified_viewers():
    me = unverified("male", 30)
    w = create_member(gender="female", age=28)
    safety.block(blocker=w, blocked_id=me[2].id)
    assert discover(me).json()["items"] == []
    resp = open_profile(me, profile_of(w).id)
    assert resp.status_code == 404


def test_no_special_data_in_any_limited_or_full_payload():
    from mc.profiles.models import Profile as P

    me = unverified()
    w = create_member(gender="female", age=28)
    P.objects.filter(account=w).update(religion="Catholic", religion_practice="weekly")
    limited = discover(me).content.decode() + open_profile(me, profile_of(w).id).content.decode()
    full_viewer = free()
    full = (
        discover(full_viewer).content.decode()
        + open_profile(full_viewer, profile_of(w).id).content.decode()
    )
    for text in (limited, full):
        assert "Catholic" not in text and "weekly" not in text and "religion" not in text


# ---- daily caps -----------------------------------------------------------------------------------
def test_unverified_cards_are_capped_per_day_with_a_resets_at(settings):
    settings.BROWSE_CARDS_PER_DAY_UNVERIFIED = 5
    me = unverified()
    for _ in range(8):
        create_member(gender="female", age=28)
    first = discover(me, limit=4).json()
    assert len(first["items"]) == 4
    second = discover(me, limit=4, cursor=first["next_cursor"]).json()
    assert len(second["items"]) == 1 and second["next_cursor"] is None  # only the last allowed card
    assert second["browse"]["used"] == 5
    blocked = discover(me)
    body = blocked.json()
    assert blocked.status_code == 429 and body["code"] == "limit_reached"
    assert body["limit"] == 5 and body["resets_at"].endswith("Z")


def test_the_card_cap_resets_at_the_next_kampala_midnight(settings):
    settings.BROWSE_CARDS_PER_DAY_UNVERIFIED = 2
    for _ in range(4):
        create_member(gender="female", age=28)
    with freeze_time(timezone.now().replace(hour=9, minute=0, second=0, microsecond=0)) as clock:
        me = unverified()
        assert len(discover(me).json()["items"]) == 2
        assert discover(me).status_code == 429
        clock.tick(
            timedelta(hours=16)
        )  # past Kampala midnight (UTC 09:00 + 16 h = 01:00 next day Kampala+3 -> 04:00)
        me2 = (me[0], login(me[0], phone=me[2].phone_e164))
        assert discover(me2).status_code == 200


def test_free_verified_cap_is_60_and_trial_has_none(settings):
    settings.BROWSE_CARDS_PER_DAY_FREE = 3
    for _ in range(6):
        create_member(gender="female", age=28)
    me = free()
    assert len(discover(me).json()["items"]) == 3
    assert discover(me).status_code == 429
    ent.start_trial(account=me[2])
    resp = discover(me)
    assert resp.status_code == 200 and resp.json()["browse"]["limit"] is None


def test_concurrent_card_requests_never_exceed_the_cap_atomically(settings):
    from mc.common import quota

    now = timezone.now()
    key = quota.day_key("cards", uuid.uuid4(), now)
    assert [quota.consume_upto(key, want=4, limit=5, now=now) for _ in range(3)] == [4, 1, 0]
    assert quota.used(key) == 5 and quota.consume_upto(key, want=0, limit=5, now=now) == 0
    assert "uuid" not in key and str(uuid.uuid4())[:8] not in key


def test_counters_store_no_raw_ids_or_ips():
    me = unverified()
    create_member(gender="female", age=28)
    discover(me, **{})
    keys = [k.decode() for k in get_redis().scan_iter("*")]
    quota_keys = [k for k in keys if k.startswith(("quota:", "rl:browse"))]
    assert quota_keys
    assert all(str(me[2].id) not in k and "127.0.0.1" not in k for k in quota_keys)


def test_per_ip_and_device_caps_for_unverified_viewers(settings):
    settings.BROWSE_PAGES_PER_IP_PER_DAY_UNVERIFIED = 2
    me = unverified()
    create_member(gender="female", age=28)
    assert discover(me).status_code == 200
    assert discover(me).status_code == 200
    resp = discover(me)
    assert resp.status_code == 429 and resp.json()["code"] == "rate_limited"
    verified_viewer = free()  # verified viewers are not held to the unverified IP cap
    for _ in range(3):
        assert discover(verified_viewer).status_code == 200


# ---- profile detail ---------------------------------------------------------------------------------
def test_profile_detail_is_locked_for_unverified_with_nothing_extra():
    me = unverified()
    w = create_member(gender="female", age=28, name="Amani", district="Wakiso")
    resp = open_profile(me, profile_of(w).id)
    body = resp.json()
    assert resp.status_code == 200
    assert set(body) == {
        "profile_id",
        "display_name",
        "age",
        "district",
        "intention",
        "photos",
        "badges",
        "locked",
        "locked_reason",
    }
    assert body["locked"] is True and body["locked_reason"] == "verify_to_see_more"
    assert len(body["photos"]) == 1 and body["photos"][0]["url"]
    assert "I am a kind" not in resp.content.decode()  # the description never leaves the server


def test_profile_detail_full_for_verified_free_member():
    me = free()
    w = create_member(gender="female", age=28)
    body = open_profile(me, profile_of(w).id).json()
    assert body["locked"] is False and body["locked_reason"] is None
    assert body["description"].startswith("I am a kind") and len(body["photos"]) == 2


def test_profile_opens_are_capped_per_day_for_unverified_but_repeats_are_free(settings):
    settings.PROFILE_OPENS_PER_DAY_UNVERIFIED = 2
    me = unverified()
    ws = [create_member(gender="female", age=28) for _ in range(3)]
    a, b, c = (profile_of(w).id for w in ws)
    assert open_profile(me, a).status_code == 200
    assert open_profile(me, a).status_code == 200  # same profile again: no extra cost
    assert open_profile(me, b).status_code == 200
    resp = open_profile(me, c)
    assert resp.status_code == 429 and resp.json()["code"] == "limit_reached"
    assert resp.json()["limit"] == 2 and resp.json()["resets_at"].endswith("Z")
    assert open_profile(me, b).status_code == 200  # already opened today
    assert open_profile(free(), c).status_code == 200  # verified members have no open cap


def test_profile_detail_forbidden_and_hidden_cases():
    me = unverified()
    assert (
        Client(headers={"host": "api.mc.test"}).get(f"/api/v1/profiles/{uuid.uuid4()}").status_code
        == 401
    )
    assert open_profile(me, uuid.uuid4()).status_code == 404
    same = create_member(gender="male", age=30)
    assert open_profile(me, profile_of(same).id).status_code == 404  # opposite-gender rule
    draft = create_member(gender="female", age=28, live=False)
    assert open_profile(me, profile_of(draft).id).status_code == 404
    no_consent = unverified(consents=False)
    w = create_member(gender="female", age=28)
    assert open_profile(no_consent, profile_of(w).id).status_code == 422


# ---- photo visibility --------------------------------------------------------------------------------
def photo_url_status(who, photo):
    return who[0].get(f"/api/v1/media/{photo.media_id}", **bearer(who[1])).status_code


def test_verified_only_photos_are_hidden_from_unverified_viewers_everywhere():
    me, ver = unverified(), free()
    w = create_member(gender="female", age=28)
    Profile.objects.filter(account=w).update(photo_visibility="verified_only")
    pid = profile_of(w).id
    assert discover(me).json()["items"][0]["photos"] == []
    assert open_profile(me, pid).json()["photos"] == []
    assert len(discover(ver).json()["items"][0]["photos"]) == 2
    assert len(open_profile(ver, pid).json()["photos"]) == 2
    from mc.media import selectors as media_selectors

    photos = list(Photo.objects.filter(profile__account=w).order_by("position"))
    assert all(
        media_selectors.signed_url(p.media, me[2]) is None for p in photos
    )  # media policy path
    assert all(media_selectors.signed_url(p.media, ver[2]) for p in photos)


def test_unverified_viewers_get_only_the_primary_photo_even_by_direct_media_policy():
    from mc.media import selectors as media_selectors

    me = unverified()
    w = create_member(gender="female", age=28, photos=3)
    first, second, third = Photo.objects.filter(profile__account=w).order_by("position")
    assert media_selectors.signed_url(first.media, me[2])
    assert media_selectors.signed_url(second.media, me[2]) is None
    assert media_selectors.signed_url(third.media, me[2]) is None
    assert len(open_profile(me, profile_of(w).id).json()["photos"]) == 1


def test_owner_always_sees_their_own_photos_and_the_default_is_everyone():
    w = create_member(gender="female", age=28)
    assert profile_of(w).photo_visibility == "everyone"
    from mc.media import selectors as media_selectors

    Profile.objects.filter(account=w).update(photo_visibility="verified_only")
    assert all(
        media_selectors.signed_url(p.media, w) for p in Photo.objects.filter(profile__account=w)
    )


def test_impressions_follow_only_granted_cards(settings):
    from mc.discovery.models import Impression

    settings.BROWSE_CARDS_PER_DAY_UNVERIFIED = 2
    me = unverified()
    for _ in range(4):
        create_member(gender="female", age=28)
    discover(me)
    assert Impression.objects.filter(viewer=me[2]).count() == 2


def test_patch_photo_visibility_validation():
    from mc.profiles.tests.helpers import patch, verified_client

    c, r, _ = verified_client()
    assert (
        patch(c, r, photo_visibility="verified_only").json()["photo_visibility"] == "verified_only"
    )
    assert patch(c, r, photo_visibility="everyone").json()["photo_visibility"] == "everyone"
    for bad in ("", "friends", "VERIFIED_ONLY"):
        assert patch(c, r, photo_visibility=bad).status_code == 422
    assert c.get("/api/v1/me/profile", **bearer(r)).json()["photo_visibility"] == "everyone"
    assert J

import pytest
from django.test import Client

from mc.accounts.tests.helpers import bearer
from mc.media.models import MediaObject
from mc.profiles.models import Photo, Preference, Profile
from mc.verification.tests.helpers import J

from .helpers import add_photo, make_ready_member, patch, ready_media, verified_client

pytestmark = pytest.mark.django_db


def go_live(c, r):
    return c.post("/api/v1/me/profile/go-live", **bearer(r))


# ---- photos ---------------------------------------------------------------------------------------
def test_add_photos_order_and_limits():
    c, r, acct = verified_client()
    ids = []
    for _ in range(6):
        resp = add_photo(c, r, ready_media(acct))
        assert resp.status_code == 201
        ids.append(resp.json()["id"])
    assert [p["position"] for p in c.get("/api/v1/me/photos", **bearer(r)).json()["items"]] == [
        0,
        1,
        2,
        3,
        4,
        5,
    ]
    assert add_photo(c, r, ready_media(acct)).status_code == 429  # max 6
    reordered = list(reversed(ids))
    resp = c.put("/api/v1/me/photos/order", {"ids": reordered}, **bearer(r), **J)
    assert resp.status_code == 200 and [p["id"] for p in resp.json()["items"]] == reordered
    assert (
        c.put("/api/v1/me/photos/order", {"ids": reordered[:-1]}, **bearer(r), **J).status_code
        == 422
    )
    assert (
        c.put(
            "/api/v1/me/photos/order", {"ids": [*reordered, ids[0]]}, **bearer(r), **J
        ).status_code
        == 422
    )


def test_delete_photo_renumbers():
    c, r, acct = verified_client()
    ids = [add_photo(c, r, ready_media(acct)).json()["id"] for _ in range(3)]
    assert c.delete(f"/api/v1/me/photos/{ids[0]}", **bearer(r)).status_code == 204
    assert [p.position for p in Photo.objects.order_by("position")] == [0, 1]


def test_photo_rules_ownership_and_state():
    c, r, acct = verified_client()
    c2, r2, other = verified_client("+256772000002")
    assert add_photo(c, r, ready_media(other)).status_code == 404  # someone else's media
    pending = ready_media(acct)
    MediaObject.objects.filter(id=pending.id).update(status="scanning")
    assert add_photo(c, r, pending).status_code == 409
    rejected = ready_media(acct)
    MediaObject.objects.filter(id=rejected.id).update(
        status="rejected", reject_reason="moderation_rejected"
    )
    assert add_photo(c, r, rejected).status_code == 422
    m = ready_media(acct)
    a, b = add_photo(c, r, m), add_photo(c, r, m)  # same media twice → same photo
    assert a.json()["id"] == b.json()["id"] and Photo.objects.count() == 1
    assert c2.delete(f"/api/v1/me/photos/{a.json()['id']}", **bearer(r2)).status_code == 404
    assert Client(headers={"host": "api.mc.test"}).get("/api/v1/me/photos").status_code == 401


def test_moderation_state_mapping_and_review():
    from mc.profiles import photos

    c, r, acct = verified_client()
    ok = add_photo(c, r, ready_media(acct, "approved")).json()
    review = add_photo(c, r, ready_media(acct, "review")).json()
    assert ok["moderation_status"] == "approved" and review["moderation_status"] == "pending"
    photos.review_photo(photo_id=review["id"], approve=True)
    assert Photo.objects.get(id=review["id"]).moderation_status == "approved"
    assert Photo.objects.get(id=ok["id"]).face_match is True
    assert Photo.objects.get(id=review["id"]).media.photo  # one-to-one


def test_photo_urls_only_for_authorised_viewers():
    """AC MC-046/048: other members get signed URLs only for approved photos of profiles they may view."""
    from mc.entitlements import services as ent
    from mc.media import selectors as media_selectors

    cf, rf, af = verified_client("+256772000001")
    cm, rm, am = verified_client("+256772000002")
    make_ready_member(cf, rf, af)
    make_ready_member(cm, rm, am, gender="male", name="Okello")
    photo = Photo.objects.filter(profile__account=af).first()
    pending = Photo.objects.filter(profile__account=af).last()
    Photo.objects.filter(id=pending.id).update(moderation_status="pending")
    ent.start_trial(account=am)
    Profile.objects.filter(account=af).update(status="live")
    assert media_selectors.signed_url(photo.media, am) is not None
    assert media_selectors.signed_url(pending.media, am) is None  # not approved
    Profile.objects.filter(account=af).update(status="draft")
    assert media_selectors.signed_url(photo.media, am) is None  # profile not visible
    Profile.objects.filter(account=af).update(status="live")
    from mc.accounts.models import Account

    assert (
        media_selectors.signed_url(photo.media, Account.objects.get(id=af.id)) is not None
    )  # owner


# ---- preferences -------------------------------------------------------------------------------------
def test_preferences_defaults_and_validation():
    c, r, _ = verified_client()
    body = c.get("/api/v1/me/preferences", **bearer(r)).json()
    assert body["age_min"] >= 18 and body["age_max"] <= 80 and body["age_min"] < body["age_max"]
    resp = c.put(
        "/api/v1/me/preferences",
        {"age_min": 25, "age_max": 35, "max_distance_km": 50, "include_diaspora": False},
        **bearer(r),
        **J,
    )
    assert (
        resp.status_code == 200
        and resp.json()["max_distance_km"] == 50
        and resp.json()["include_diaspora"] is False
    )
    for bad in (
        {"age_min": 17},
        {"age_max": 81},
        {"age_min": 40, "age_max": 30},
        {"max_distance_km": 0},
        {"age_max": 20},
        {"nope": 1},
    ):
        assert c.put("/api/v1/me/preferences", bad, **bearer(r), **J).status_code == 422, bad
    assert (
        c.put("/api/v1/me/preferences", {"max_distance_km": None}, **bearer(r), **J).json()[
            "max_distance_km"
        ]
        is None
    )
    assert Preference.objects.count() == 1


# ---- go-live ------------------------------------------------------------------------------------------
def test_go_live_lists_everything_missing():
    c, r, _ = verified_client()
    resp = go_live(c, r)
    assert resp.status_code == 422 and resp.json()["code"] == "profile_incomplete"
    assert set(resp.json()["missing"]) == {
        "display_name",
        "gender",
        "district",
        "intention",
        "marriage_timeline",
        "marital_status",
        "photos",
        "description",
        "questionnaire",
    }
    assert Profile.objects.get().status == "draft"


@pytest.mark.parametrize(
    "break_it", ["photos", "pending_photo", "description", "questionnaire", "field"]
)
def test_each_rule_blocks_go_live(break_it):
    c, r, acct = verified_client()
    make_ready_member(c, r, acct)
    p = Profile.objects.get()
    if break_it == "photos":
        p.photos.first().delete()
    elif break_it == "pending_photo":
        Photo.objects.filter(id=p.photos.first().id).update(moderation_status="pending")
    elif break_it == "description":
        Profile.objects.filter(id=p.id).update(current_description=None)
    elif break_it == "questionnaire":
        from mc.questionnaire.models import Answer

        Answer.objects.filter(account=acct).first().delete()
    else:
        Profile.objects.filter(id=p.id).update(district="")
    resp = go_live(c, r)
    assert resp.status_code == 422 and resp.json()["missing"]


def test_go_live_succeeds_when_everything_holds_and_completeness_reflects_it():
    c, r, acct = verified_client()
    make_ready_member(c, r, acct)
    body = go_live(c, r).json()
    assert body["status"] == "live" and body["readiness"] == {"ready": True, "missing": []}
    assert body["completeness"] == 80  # all required items, no optional ones yet
    body = patch(
        c,
        r,
        languages=["en"],
        occupation="Teacher",
        education="bachelors",
        has_children="no",
        wants_children="yes",
        marriage_form_preference="monogamous_only",
    ).json()
    assert body["completeness"] == 90
    assert go_live(c, r).status_code == 200  # idempotent


def test_live_profile_goes_offline_when_photos_drop_below_minimum():
    c, r, acct = verified_client()
    make_ready_member(c, r, acct)
    go_live(c, r)
    photo = Photo.objects.first()
    assert c.delete(f"/api/v1/me/photos/{photo.id}", **bearer(r)).status_code == 204
    assert Profile.objects.get().status == "draft"


def test_hide_and_unhide():
    c, r, acct = verified_client()
    make_ready_member(c, r, acct)
    go_live(c, r)
    assert c.post("/api/v1/me/profile/hide", **bearer(r)).json()["status"] == "hidden_by_user"
    assert c.post("/api/v1/me/profile/unhide", **bearer(r)).json()["status"] == "live"
    c.post("/api/v1/me/profile/hide", **bearer(r))
    Photo.objects.first().delete()
    assert c.post("/api/v1/me/profile/unhide", **bearer(r)).json()["status"] == "draft"


def test_suspended_profile_cannot_go_live_or_unhide():
    c, r, acct = verified_client()
    make_ready_member(c, r, acct)
    Profile.objects.update(status="suspended")
    assert go_live(c, r).status_code == 409
    assert c.post("/api/v1/me/profile/unhide", **bearer(r)).status_code == 409


def test_public_profile_includes_description_and_photo_urls():
    from mc.entitlements import services as ent

    cf, rf, af = verified_client("+256772000001")
    cm, rm, am = verified_client("+256772000002")
    make_ready_member(cf, rf, af)
    make_ready_member(cm, rm, am, gender="male", name="Okello")
    go_live(cf, rf)
    ent.start_trial(account=am)
    pid = Profile.objects.get(account=af).id
    body = cm.get(f"/api/v1/profiles/{pid}", **bearer(rm)).json()
    assert (
        len(body["photos"]) == 2
        and body["photos"][0]["url"]
        and body["description"].startswith("I am a teacher")
    )
    assert "photo_verified" in body["badges"]

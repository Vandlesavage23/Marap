import json

import pytest
from django.test import Client
from freezegun import freeze_time

from devtools.factories import create_member
from mc.accounts.tests.helpers import bearer, login
from mc.discovery.models import Impression, ModelVersion
from mc.entitlements import services as ent
from mc.verification.tests.helpers import J

pytestmark = pytest.mark.django_db


def member_client(phone="+256772100001", **kw):
    """A live, verified member who can log in (login creates/uses the same phone's account)."""
    acct = create_member(phone=phone, **kw)
    c = Client(headers={"host": "api.mc.test"})
    r = login(c, phone=phone)
    assert r.status_code in (200, 201)
    return c, r, acct


def discover(c, r, **params):
    qs = "&".join(f"{k}={v}" for k, v in params.items())
    return c.get(f"/api/v1/discovery?{qs}", **bearer(r))


def test_requires_auth():
    assert Client(headers={"host": "api.mc.test"}).get("/api/v1/discovery").status_code == 401


def test_browse_capability_enforced():
    c, r, acct = member_client(gender="male", age=30)
    resp = discover(c, r)
    assert resp.status_code == 403
    body = resp.json()
    assert body["code"] == "entitlement_required" and body["capability"] == "browse"
    ent.start_trial(account=acct)
    assert discover(c, r).status_code == 200


def test_viewer_must_have_live_profile():
    c, r, acct = member_client(gender="male", age=30, live=False)
    ent.start_trial(account=acct)
    resp = discover(c, r)
    assert resp.status_code == 422 and resp.json()["code"] == "profile_incomplete"


def test_card_shape_has_no_numeric_score_and_never_leaks_private_data():
    c, r, me = member_client(gender="male", age=30)
    ent.start_trial(account=me)
    create_member(gender="female", age=28, name="Amani", district="Wakiso")
    resp = discover(c, r)
    body = resp.json()
    card = body["items"][0]
    assert set(card) == {
        "profile_id",
        "display_name",
        "age",
        "district",
        "photos",
        "intention",
        "marriage_timeline",
        "marital_status_label",
        "badges",
        "why",
        "discuss",
        "score_band",
    }
    assert card["score_band"] in ("strong", "good", "possible") and card["display_name"] == "Amani"
    assert len(card["photos"]) == 2 and card["photos"][0]["w"] == 800
    text = resp.content.decode()
    for banned in ('score":', "religion", "birth", "phone", "+2567", "location_lat"):
        assert banned not in text


def test_pagination_with_signed_cursor_covers_everyone_once():
    c, r, me = member_client(gender="male", age=30)
    ent.start_trial(account=me)
    women = [
        create_member(gender="female", age=28, district=d)
        for d in ["A", "B", "C", "D", "E", "F", "G"]
    ]
    seen, cursor = [], None
    while True:
        resp = discover(c, r, limit=3, **({"cursor": cursor} if cursor else {}))
        assert resp.status_code == 200
        seen += [i["profile_id"] for i in resp.json()["items"]]
        cursor = resp.json()["next_cursor"]
        if not cursor:
            break
    assert len(seen) == len(set(seen)) == len(women)


def test_tampered_foreign_and_garbage_cursors_rejected():
    c, r, me = member_client(gender="male", age=30)
    ent.start_trial(account=me)
    for _ in range(5):
        create_member(gender="female", age=28)
    cursor = discover(c, r, limit=2).json()["next_cursor"]
    assert cursor
    bad = [
        cursor[:-3] + ("AAA" if cursor[-3:] != "AAA" else "BBB"),
        "garbage",
        cursor + "x",
        "a:b:c",
    ]
    for b in bad:
        resp = discover(c, r, cursor=b)
        assert resp.status_code == 422 and resp.json()["code"] == "validation_error", b
    # a cursor minted for another viewer is useless
    c2, r2, other = member_client("+256772100002", gender="male", age=31)
    ent.start_trial(account=other)
    assert discover(c2, r2, cursor=cursor).status_code == 422


def test_cursor_expires_after_30_minutes():
    from mc.common.errors import ValidationFailed
    from mc.discovery import services

    with freeze_time("2026-10-15 10:00:00") as t:
        me = create_member(gender="male", age=30)
        ent.start_trial(account=me)
        for _ in range(4):
            create_member(gender="female", age=28)
        cursor = services.next_candidates(me, cursor=None, limit=2)["next_cursor"]
        t.tick(29 * 60)
        assert services.next_candidates(me, cursor=cursor, limit=2)["items"]
        t.tick(2 * 60)  # 31 minutes after minting
        with pytest.raises(ValidationFailed) as ei:
            services.next_candidates(me, cursor=cursor, limit=2)
    assert ei.value.extra["cursor_expired"] is True


def test_impressions_recorded_with_model_version_and_position():
    c, r, me = member_client(gender="male", age=30)
    ent.start_trial(account=me)
    for _ in range(3):
        create_member(gender="female", age=28)
    discover(c, r)
    imps = list(Impression.objects.filter(viewer=me).order_by("position"))
    assert [i.position for i in imps] == [0, 1, 2]
    assert {i.model_version for i in imps} == {"v1-weighted"}
    assert ModelVersion.objects.filter(name="v1-weighted", active=True).exists()
    assert all(0 <= float(i.score) <= 1.05 for i in imps)


def test_shown_candidates_are_hidden_on_the_next_fresh_request():
    c, r, me = member_client(gender="male", age=30)
    ent.start_trial(account=me)
    create_member(gender="female", age=28, name="Amani")
    assert len(discover(c, r).json()["items"]) == 1
    assert len(discover(c, r).json()["items"]) == 1  # pool exhausted → fallback shows recent again
    create_member(gender="female", age=28, name="Zawadi")
    names = [i["display_name"] for i in discover(c, r).json()["items"]]
    assert names == ["Zawadi"]  # the new one first; recently seen hidden while others exist


def test_feedback_pass_and_not_relevant():
    c, r, me = member_client(gender="male", age=30)
    ent.start_trial(account=me)
    create_member(gender="female", age=28, name="Amani")
    create_member(gender="female", age=28, name="Zawadi")
    items = discover(c, r).json()["items"]
    assert len(items) == 2
    pid = items[0]["profile_id"]
    assert (
        c.post(
            "/api/v1/discovery/feedback",
            {"profile_id": pid, "action": "not_relevant"},
            **bearer(r),
            **J,
        ).status_code
        == 204
    )
    assert Impression.objects.filter(action="not_relevant").count() == 1
    Impression.objects.update(
        shown_at="2020-01-01T00:00:00Z"
    )  # long ago: only not_relevant keeps it hidden
    again = {i["profile_id"] for i in discover(c, r).json()["items"]}
    assert pid not in again and len(again) == 1
    assert (
        c.post(
            "/api/v1/discovery/feedback",
            {"profile_id": items[1]["profile_id"], "action": "pass"},
            **bearer(r),
            **J,
        ).status_code
        == 204
    )
    # never-shown profile → 404; invalid action → 422; foreign fields → 422
    stranger = create_member(gender="female", age=28)
    from mc.profiles.models import Profile

    sp = str(Profile.objects.get(account=stranger).id)
    assert (
        c.post(
            "/api/v1/discovery/feedback", {"profile_id": sp, "action": "pass"}, **bearer(r), **J
        ).status_code
        == 404
    )
    assert (
        c.post(
            "/api/v1/discovery/feedback", {"profile_id": pid, "action": "like"}, **bearer(r), **J
        ).status_code
        == 422
    )
    assert (
        c.post(
            "/api/v1/discovery/feedback",
            {"profile_id": pid, "action": "pass", "x": 1},
            **bearer(r),
            **J,
        ).status_code
        == 422
    )
    assert (
        Client(headers={"host": "api.mc.test"})
        .post("/api/v1/discovery/feedback", {}, **J)
        .status_code
        == 401
    )


def test_scraping_limits(settings):
    c, r, me = member_client(gender="male", age=30)
    ent.start_trial(account=me)
    for _ in range(4):
        create_member(gender="female", age=28)
    settings.DISCOVERY_DAILY_VIEWS_LIMIT = 4
    assert discover(c, r).status_code == 200
    resp = discover(c, r)
    assert resp.status_code == 429 and resp.json()["code"] == "limit_reached"
    settings.DISCOVERY_DAILY_VIEWS_LIMIT = 300
    settings.DISCOVERY_REQUESTS_PER_HOUR = 2
    from mc.common.redis import get_redis

    get_redis().flushdb()
    login_again = login(c, phone="+256772100001")
    for _ in range(2):
        assert discover(c, login_again).status_code == 200
    resp = discover(c, login_again)
    assert (
        resp.status_code == 429
        and resp.json()["code"] == "rate_limited"
        and int(resp["Retry-After"]) > 0
    )


def test_blocked_or_deleted_between_pages_disappear():
    from mc.safety.models import Block

    c, r, me = member_client(gender="male", age=30)
    ent.start_trial(account=me)
    women = [create_member(gender="female", age=28) for _ in range(4)]
    page1 = discover(c, r, limit=2).json()
    Block.objects.create(blocker=me, blocked=women[0])
    Block.objects.create(blocker=me, blocked=women[1])
    Block.objects.create(blocker=me, blocked=women[2])
    Block.objects.create(blocker=me, blocked=women[3])
    page2 = discover(c, r, limit=2, cursor=page1["next_cursor"]).json()
    assert page2["items"] == []  # blocked at serve time, even though the snapshot still listed them
    _ = json

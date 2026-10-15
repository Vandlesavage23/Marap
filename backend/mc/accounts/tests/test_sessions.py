import uuid

import jwt
import pytest
from django.conf import settings
from django.test import Client
from freezegun import freeze_time

from mc.accounts import services
from mc.accounts.models import Account, Session

from .helpers import PHONE, bearer, login

pytestmark = pytest.mark.django_db
J = {"content_type": "application/json"}


def refresh(api, token):
    return api.post("/api/v1/auth/refresh", {"refresh": token}, **J)


def test_access_token_lives_15_minutes_and_has_required_claims(api):
    r = login(api).json()
    claims = jwt.decode(r["access"], options={"verify_signature": False})
    assert claims["exp"] - claims["iat"] == 15 * 60
    assert {"sub", "sid", "ver"} <= set(claims)
    assert jwt.get_unverified_header(r["access"])["alg"] == "EdDSA"


def test_me_requires_auth_and_returns_summary(api):
    assert api.get("/api/v1/me").status_code == 401
    r = login(api)
    me = api.get("/api/v1/me", **bearer(r))
    assert me.status_code == 200 and me.json()["status"] == "pending_verification"
    assert "legal_name" not in me.json()


def test_expired_access_token_returns_token_expired(api):
    with freeze_time("2026-01-01 10:00:00") as t:
        r = login(api)
        t.tick(16 * 60)
        resp = api.get("/api/v1/me", **bearer(r))
    assert resp.status_code == 401 and resp.json()["code"] == "token_expired"


def _forge_hs256(claims):
    import base64
    import hashlib
    import hmac
    import json

    def b64(raw: bytes) -> str:
        return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()

    signing = (
        b64(json.dumps({"alg": "HS256", "typ": "JWT"}).encode())
        + "."
        + b64(json.dumps(claims).encode())
    )
    sig = hmac.new(
        settings.MC_JWT_PUBLIC_KEY_PEM.encode(), signing.encode(), hashlib.sha256
    ).digest()
    return signing + "." + b64(sig)


def test_forged_and_alg_none_tokens_rejected(api):
    r = login(api).json()
    claims = jwt.decode(r["access"], options={"verify_signature": False})
    none_token = jwt.encode(claims, key=None, algorithm="none")
    hs = _forge_hs256(claims)  # classic key-confusion: HMAC signed with the public key
    for bad in (none_token, hs, "garbage"):
        resp = api.get("/api/v1/me", HTTP_AUTHORIZATION=f"Bearer {bad}")
        assert resp.status_code == 401


def test_refresh_rotates_and_old_token_is_dead(api):
    first = login(api).json()
    second = refresh(api, first["refresh"])
    assert second.status_code == 200
    new = second.json()
    assert new["refresh"] != first["refresh"] and new["access"]
    assert api.get("/api/v1/me", **bearer(second)).status_code == 200


def test_refresh_reuse_revokes_whole_chain(api):
    first = login(api).json()
    second = refresh(api, first["refresh"]).json()
    third = refresh(api, second["refresh"]).json()
    # attacker replays the first (already rotated) token
    assert refresh(api, first["refresh"]).status_code == 401
    # the legitimately newest token is now revoked too
    assert refresh(api, third["refresh"]).status_code == 401
    assert api.get("/api/v1/me", HTTP_AUTHORIZATION=f"Bearer {third['access']}").status_code == 401
    assert not Session.objects.filter(revoked_at__isnull=True).exists()


def test_reuse_does_not_touch_other_logins_of_same_account(api):
    a = login(api).json()
    b = login(api, device={"install_id": str(uuid.uuid4()), "platform": "ios"}).json()
    refresh(api, a["refresh"])
    refresh(api, a["refresh"])  # reuse → only chain A dies
    assert refresh(api, b["refresh"]).status_code == 200


def test_unknown_and_expired_refresh_tokens_rejected(api):
    assert refresh(api, "nope").status_code == 401
    with freeze_time("2026-01-01") as t:
        tok = login(api).json()["refresh"]
        t.tick(31 * 24 * 3600)
        assert refresh(api, tok).status_code == 401


def test_logout_revokes_session_immediately(api):
    r = login(api)
    assert api.post("/api/v1/auth/logout", **bearer(r)).status_code == 204
    assert api.get("/api/v1/me", **bearer(r)).status_code == 401
    assert refresh(api, r.json()["refresh"]).status_code == 401


def test_sessions_list_marks_current_and_revoke_works(api):
    r1 = login(api)
    r2 = login(
        api, device={"install_id": str(uuid.uuid4()), "platform": "ios", "app_version": "1.0.0"}
    )
    items = api.get("/api/v1/me/sessions", **bearer(r2)).json()["items"]
    assert len(items) == 2 and sum(i["current"] for i in items) == 1
    other = next(i for i in items if not i["current"])
    assert api.delete(f"/api/v1/me/sessions/{other['id']}", **bearer(r2)).status_code == 204
    assert api.get("/api/v1/me", **bearer(r1)).status_code == 401  # revoked device is out
    assert len(api.get("/api/v1/me/sessions", **bearer(r2)).json()["items"]) == 1


def test_cannot_revoke_someone_elses_session(api):
    mine = login(api)
    theirs = login(Client(headers={"host": "api.mc.test"}), phone="+256772000077")
    their_session = Session.objects.get(account__phone_e164="+256772000077")
    r = api.delete(f"/api/v1/me/sessions/{their_session.id}", **bearer(mine))
    assert r.status_code == 404
    assert api.get("/api/v1/me", **bearer(theirs)).status_code == 200
    assert api.delete(f"/api/v1/me/sessions/{uuid.uuid4()}", **bearer(mine)).status_code == 404


def test_deactivated_account_token_stops_working(api):
    r = login(api)
    Account.objects.filter(phone_e164=PHONE).update(status="deactivated")
    assert api.get("/api/v1/me", **bearer(r)).status_code == 401


def test_revoke_all_sessions_service(api):
    login(api)
    login(api)
    acct = Account.objects.get(phone_e164=PHONE)
    assert services.revoke_all_sessions(account=acct) == 2
    assert not Session.objects.filter(revoked_at__isnull=True).exists()


def test_refresh_token_stored_only_as_hash(api):
    tok = login(api).json()["refresh"]
    assert not Session.objects.filter(refresh_token_hash=tok).exists()
    assert Session.objects.get().refresh_token_hash != tok

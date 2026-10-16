import logging
import uuid
from datetime import timedelta

import pytest
from django.test import Client
from django.utils import timezone

from mc.accounts.models import Session
from mc.adminportal import policies, totp
from mc.adminportal.models import StaffSession
from mc.adminportal.tests.helpers import HOST, client, full_login, next_code, sso_login, staff
from mc.audit.models import AuditEvent
from mc.interests.tests.helpers import member

pytestmark = pytest.mark.django_db


def test_unauthenticated_requests_redirect_to_login():
    c = client()
    for path in (
        "/", "/users", "/verification", "/safety", "/payments", "/privacy", "/audit", "/flags",
        "/payments/reconciliation", "/dashboards/funnel", "/dashboards/density",
    ):  # fmt: skip
        r = c.get(path)
        assert r.status_code == 302 and r["Location"].endswith("/login"), path


def test_sso_only_for_preprovisioned_active_staff_in_allowed_domain():
    s = staff(["support"])
    assert sso_login(client(), s).status_code == 302
    # unknown person (valid SSO, same domain) → generic 401, no row created
    from mc.adminportal.models import StaffUser

    stranger = StaffUser(email="eve@marriageconnect.ug", name="Eve", roles=[])
    assert sso_login(client(), stranger).status_code == 401
    outsider = StaffUser(email="ann@gmail.com", name="Ann", roles=["support"])
    assert sso_login(client(), outsider).status_code == 401
    assert sso_login(client(), s, code="c2", verified=False).status_code == 401
    s.active = False
    s.save()
    assert sso_login(client(), s, code="c3").status_code == 401
    assert AuditEvent.objects.filter(action="admin.login_failed").count() == 4


def test_sso_state_mismatch_rejected():
    staff(["support"])
    c = client()
    c.get("/login")
    assert c.get("/sso/callback", {"code": "x", "state": "forged"}).status_code == 401


def test_mfa_is_mandatory_enrols_on_first_use_and_codes_cannot_be_replayed():
    s = staff(["support"])
    c = client()
    sso_login(c, s)
    assert c.get("/users").status_code == 302 and c.get("/users")["Location"].endswith("/mfa")
    assert c.get("/mfa").status_code == 200
    assert c.post("/mfa", {"code": "000000"}).status_code == 200  # wrong code → form again
    code = next_code(s)
    assert c.post("/mfa", {"code": code}).status_code == 302
    s.refresh_from_db()
    assert s.totp_enrolled_at is not None
    assert c.get("/users").status_code == 200
    # replaying the same code on another session fails
    c2 = client()
    sso_login(c2, s, code="c9")
    c2.get("/mfa")
    assert c2.post("/mfa", {"code": code}).status_code == 200
    assert totp.verify(str(s.totp_secret), code, last_step=s.totp_last_step) is None


def test_session_expiry_logout_and_cookie_flags():
    s = staff(["support"])
    c = full_login(s)
    cookie = c.cookies["mc_admin"]
    assert cookie["httponly"] and cookie["samesite"] == "Strict"
    StaffSession.objects.update(expires_at=timezone.now() - timedelta(seconds=1))
    assert c.get("/users").status_code == 302
    c = full_login(s)
    assert c.post("/logout").status_code == 302
    assert c.get("/users").status_code == 302


def test_forged_cookie_and_deactivated_staff_are_rejected():
    s = staff(["support"])
    c = full_login(s)
    c.cookies["mc_admin"] = "forged"
    assert c.get("/users").status_code == 302
    c = full_login(s)
    s.active = False
    s.save()
    assert c.get("/users").status_code == 302


def test_role_matrix_over_http():
    paths = {
        "/users": "user.read_limited", "/verification": "verification.queue", "/safety": "safety.queue",
        "/payments": "payments.status", "/privacy": "privacy.requests", "/audit": "audit.all",
        "/payments/reconciliation": "payments.reconciliation", "/dashboards/funnel": "dashboard.funnel",
        "/dashboards/density": "dashboard.density", "/flags": "config.flags",
    }  # fmt: skip
    for role in policies.PERMISSIONS:
        s = staff([role], email=f"{role}@marriageconnect.ug")
        c = full_login(s)
        for path, perm in paths.items():
            expected = 200 if perm in policies.permissions_of(s) else 403
            assert c.get(path).status_code == expected, (role, path)


def test_scenario_12_denied_access_is_403_audited_and_alerted(caplog):
    s = staff(["support"])
    c = full_login(s)
    with caplog.at_level(logging.WARNING, logger="mc.adminportal"):
        assert c.get("/audit").status_code == 403
        assert c.get("/safety").status_code == 403
    denied = AuditEvent.objects.filter(action="admin.denied")
    assert denied.count() == 2 and denied.first().actor_id == s.id
    assert [r for r in caplog.records if getattr(r, "alert", "") == "admin_access_denied"]


def test_allowed_views_are_audited_and_member_lookup_is_limited():
    s = staff(["support"])
    who = member("female")
    c = full_login(s)
    r = c.get("/users", {"q": str(who[2].id)})
    body = r.content.decode()
    assert r.status_code == 200 and str(who[2].id) in body
    assert who[2].phone_e164 not in body  # no phone, no profile text
    assert AuditEvent.objects.filter(action="admin.view_user", target_id=who[2].id).exists()
    assert AuditEvent.objects.filter(action="admin.view").exists()


def test_sensitive_action_needs_step_up_then_works_and_is_audited():
    s = staff(["support"])
    who = member(
        "female",
    )
    c = full_login(s)
    url = f"/users/{who[2].id}/revoke-sessions"
    StaffSession.objects.update(reauth_at=timezone.now() - timedelta(minutes=30))
    r = c.post(url, {"reason": "reported hijack"})
    assert r.status_code == 302 and "/stepup" in r["Location"]
    assert c.post("/stepup?next=/users", {"code": next_code(s)}).status_code == 302
    r = c.post(url, {"reason": "reported hijack"})
    assert r.status_code == 200 and "Signed out" in r.content.decode()
    assert AuditEvent.objects.filter(
        action="support.revoke_sessions", reason="reported hijack"
    ).exists()
    assert c.post(url, {"reason": ""}).status_code == 200  # reason required
    assert not Session.objects.filter(account=who[2], revoked_at__isnull=True).exists()


def test_csrf_is_enforced_on_portal_posts():
    s = staff(["support"])
    c = full_login(s)
    strict = Client(headers={"host": HOST}, enforce_csrf_checks=True)
    strict.cookies = c.cookies
    assert strict.post("/logout").status_code == 403


def test_ip_allowlist(settings):
    settings.ADMIN_IP_ALLOWLIST = ["10.1.0.0/16"]
    s = staff(["support"])
    c = client()
    assert c.get("/login", REMOTE_ADDR="203.0.113.5").status_code == 403
    assert c.get("/login", REMOTE_ADDR="10.1.2.3").status_code == 200
    assert c.get("/users", REMOTE_ADDR="203.0.113.5").status_code == 403
    assert AuditEvent.objects.filter(action="admin.denied").exists()
    _ = s


def test_security_headers_on_admin_host_only():
    r = client().get("/login")
    assert (
        "frame-ancestors 'none'" in r["Content-Security-Policy"]
        and r["Cache-Control"] == "no-store"
    )
    assert "Content-Security-Policy" not in Client(headers={"host": "api.mc.test"}).get(
        "/api/v1/health"
    )


def test_create_staff_command():
    from django.core.management import call_command

    call_command(
        "create_staff",
        "bob@marriageconnect.ug",
        "--name",
        "Bob",
        "--role",
        "support",
        "--role",
        "trust_safety",
    )
    from mc.adminportal.models import StaffUser

    assert StaffUser.objects.get(email="bob@marriageconnect.ug").roles == [
        "support",
        "trust_safety",
    ]
    assert AuditEvent.objects.filter(action="staff.created").exists()
    _ = uuid

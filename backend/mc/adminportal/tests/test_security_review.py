"""Regression tests from the adversarial security review (open redirects, TOTP hardening)."""

import pytest

from mc.adminportal import totp
from mc.adminportal.tests.helpers import client, full_login, next_code, sso_login, staff
from mc.audit.models import AuditEvent

pytestmark = pytest.mark.django_db

EVIL = [
    "//evil.example",
    "https://evil.example/x",
    "/\\evil.example",
    "\\\\evil.example",
    "/\t/evil.example",
]


@pytest.mark.parametrize("nxt", EVIL)
def test_mfa_next_cannot_redirect_off_site(nxt):
    s = staff(["support"])
    c = client()
    sso_login(c, s)
    c.get("/mfa")
    r = c.post("/mfa?next=" + nxt.replace("\\", "%5C").replace("\t", "%09"), {"code": next_code(s)})
    assert r.status_code == 302 and r["Location"] == "/"


@pytest.mark.parametrize("nxt", EVIL)
def test_stepup_next_cannot_redirect_off_site(nxt):
    s = staff(["support"])
    c = full_login(s)
    r = c.post(
        "/stepup?next=" + nxt.replace("\\", "%5C").replace("\t", "%09"), {"code": next_code(s)}
    )
    assert r.status_code == 302 and r["Location"] == "/"


def test_mfa_next_keeps_local_paths():
    s = staff(["support"])
    c = client()
    sso_login(c, s)
    c.get("/mfa")
    assert c.post("/mfa?next=/users", {"code": next_code(s)})["Location"] == "/users"


def test_non_ascii_digits_are_a_clean_failure_not_a_crash():
    assert totp.verify("JBSWY3DPEHPK3PXP", "١٢٣٤٥٦") is None


def test_mfa_guessing_is_rate_limited_and_audited():
    s = staff(["support"])
    c = client()
    sso_login(c, s)
    c.get("/mfa")
    codes = [c.post("/mfa", {"code": "000000"}).status_code for _ in range(15)]
    assert 429 in codes
    # even the right code is refused while locked out
    assert c.post("/mfa", {"code": next_code(s)}).status_code == 429
    assert AuditEvent.objects.filter(action="admin.mfa_failed").exists()


def test_stepup_guessing_is_rate_limited():
    s = staff(["support"])
    c = full_login(s)
    codes = [c.post("/stepup", {"code": "000000"}).status_code for _ in range(15)]
    assert 429 in codes

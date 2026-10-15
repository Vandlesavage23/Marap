import time

from django.core import signing
from django.test import Client

from mc.adminportal import auth, totp
from mc.adminportal.models import StaffUser
from mc.adminportal.providers.sso import FakeSso, SsoIdentity

HOST = "admin.mc.test"


def staff(roles: list[str], email: str = "ann@marriageconnect.ug") -> StaffUser:
    return StaffUser.objects.create(email=email, name="Ann", roles=roles)


def client() -> Client:
    return Client(headers={"host": HOST}, enforce_csrf_checks=False)


def sso_login(c: Client, s: StaffUser, *, code: str = "c1", verified: bool = True):
    FakeSso.codes[code] = SsoIdentity("sub-" + s.email, s.email, s.name, verified)
    start = c.get("/login")
    state = start.context["sso_url"].split("state=")[1].split("&")[0]
    return c.get("/sso/callback", {"code": code, "state": state})


def next_code(s: StaffUser) -> str:
    s.refresh_from_db()
    # a fresh step each call so replay protection never trips the helper
    step = max(totp.current_step(), s.totp_last_step + 1)
    return totp._code(str(s.totp_secret), step)


def full_login(s: StaffUser) -> Client:
    c = client()
    assert sso_login(c, s).status_code == 302
    c.get("/mfa")  # creates the pending secret
    r = c.post("/mfa", {"code": next_code(s)})
    assert r.status_code == 302, r.content
    return c


_ = (auth, signing, time)

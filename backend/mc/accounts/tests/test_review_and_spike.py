import logging

import pytest
from django.core.management import call_command
from django.test import Client

from mc.accounts.models import Account
from mc.accounts.providers.sms import FakeSms
from mc.audit.models import AuditEvent
from mc.verification.tests.helpers import J

pytestmark = pytest.mark.django_db
PHONE = "+256772888001"


def post(path, body):
    return Client(headers={"host": "api.mc.test"}).post(f"/api/v1/auth/otp/{path}", body, **J)


def test_review_account_is_disabled_by_default():
    assert post("start", {"phone": PHONE}).status_code == 202
    assert FakeSms.outbox  # a normal SMS was sent
    assert post("verify", {"phone": PHONE, "code": "123456"}).status_code == 422


def test_review_account_signs_in_with_fixed_code_without_sms_and_is_audited(settings):
    settings.REVIEW_ACCOUNT_PHONE, settings.REVIEW_ACCOUNT_CODE = PHONE, "424242"
    call_command("create_review_account", "--confirm")
    assert Account.objects.filter(phone_e164=PHONE).exists()
    assert post("start", {"phone": PHONE}).status_code == 202 and FakeSms.outbox == []
    assert post("verify", {"phone": PHONE, "code": "000000"}).status_code == 422
    r = post("verify", {"phone": PHONE, "code": "424242"})
    assert r.status_code == 200 and r.json()["access"]
    assert AuditEvent.objects.filter(action="auth.review_account_login").count() == 1
    # other numbers are unaffected by the fixed code
    post("start", {"phone": "+256772888002"})
    assert post("verify", {"phone": "+256772888002", "code": "424242"}).status_code == 422


def test_review_code_attempts_are_rate_limited(settings):
    settings.REVIEW_ACCOUNT_PHONE, settings.REVIEW_ACCOUNT_CODE = PHONE, "424242"
    codes = [post("verify", {"phone": PHONE, "code": f"{i:06d}"}).status_code for i in range(12)]
    assert 429 in codes


def test_command_refuses_without_configuration():
    from django.core.management.base import CommandError

    with pytest.raises(CommandError):
        call_command("create_review_account", "--confirm")


def test_otp_send_spike_raises_one_alert(settings, caplog):
    settings.OTP_SPIKE_ALERT_PER_HOUR = 3
    settings.OTP_SENDS_PER_IP_PER_HOUR = 100
    with caplog.at_level(logging.WARNING):
        for i in range(5):
            post("start", {"phone": f"+25677299900{i}"})
    alerts = [r for r in caplog.records if getattr(r, "alert", "") == "otp_send_spike"]
    assert len(alerts) == 1


def test_get_consents_returns_current_map_and_requires_auth():
    from mc.accounts.tests.helpers import bearer
    from mc.verification.tests.helpers import CONSENTS, new_user

    c, r = new_user("+256772888050")
    got = c.get("/api/v1/me/consents", **bearer(r)).json()["consents"]
    assert set(got) == {x["kind"] for x in CONSENTS} and all(v["granted"] for v in got.values())
    assert Client(headers={"host": "api.mc.test"}).get("/api/v1/me/consents").status_code == 401


def test_explicit_null_push_token_clears_it_but_omitting_it_keeps_it():
    from mc.accounts.models import Device
    from mc.accounts.tests.helpers import bearer
    from mc.verification.tests.helpers import new_user

    c, r = new_user("+256772888060")
    body = {"install_id": "11111111-1111-4111-8111-111111111111", "platform": "android"}
    c.post("/api/v1/me/devices", {**body, "push_token": "tok-1"}, **bearer(r), **J)
    assert Device.objects.get(install_id=body["install_id"]).push_token == "tok-1"
    c.post(
        "/api/v1/me/devices", {**body, "app_version": "1.2"}, **bearer(r), **J
    )  # omitted → unchanged
    assert Device.objects.get(install_id=body["install_id"]).push_token == "tok-1"
    c.post(
        "/api/v1/me/devices", {**body, "push_token": None}, **bearer(r), **J
    )  # explicit null → cleared
    d = Device.objects.get(install_id=body["install_id"])
    assert d.push_token is None
    listing = c.get("/api/v1/me/devices", **bearer(r)).json()["items"]
    assert (
        next(i for i in listing if i["install_id"] == body["install_id"])["push_enabled"] is False
    )

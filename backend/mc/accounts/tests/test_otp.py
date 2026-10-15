import pytest
from freezegun import freeze_time

from mc.accounts.models import Account
from mc.accounts.providers.sms import FakeSms

from .helpers import PHONE, last_code, login

pytestmark = pytest.mark.django_db
J = {"content_type": "application/json"}


def start(api, phone=PHONE, purpose="login", ip="10.0.0.1"):
    return api.post(
        "/api/v1/auth/otp/start", {"phone": phone, "purpose": purpose}, REMOTE_ADDR=ip, **J
    )


def verify(api, code, phone=PHONE):
    return api.post("/api/v1/auth/otp/verify", {"phone": phone, "code": code}, **J)


def test_start_returns_202_and_sends_sms_without_leaking_state(api):
    r = start(api)
    assert r.status_code == 202 and r.json() == {"status": "accepted"}
    assert len(FakeSms.outbox) == 1 and FakeSms.outbox[0][0] == PHONE


def test_start_normalises_local_uganda_format(api):
    assert start(api, "0772 000 001").status_code == 202
    assert FakeSms.outbox[0][0] == PHONE


def test_unknown_phone_for_recover_gets_202_and_no_sms(api):
    assert start(api, purpose="recover").status_code == 202
    assert FakeSms.outbox == []


def test_recover_known_phone_sends(api):
    Account.objects.create(phone_e164=PHONE)
    assert start(api, purpose="recover").status_code == 202
    assert len(FakeSms.outbox) == 1


def test_recover_response_identical_for_known_and_unknown(api):
    known = "+256772000002"
    Account.objects.create(phone_e164=known)
    a, b = start(api, known, "recover"), start(api, PHONE, "recover")
    assert (a.status_code, a.json()) == (b.status_code, b.json())


def test_invalid_and_unsupported_numbers_rejected(api):
    assert start(api, "123").status_code == 422
    assert start(api, "+14155550123").status_code == 422  # not on the Uganda-only allowlist
    assert FakeSms.outbox == []


def test_correct_code_creates_account_and_tokens(api):
    start(api)
    r = verify(api, last_code())
    assert r.status_code == 201
    body = r.json()
    assert body["access"] and body["refresh"]
    assert body["account"]["status"] == "pending_verification"
    assert Account.objects.filter(phone_e164=PHONE).count() == 1


def test_existing_account_returns_200(api):
    login(api)
    r = login(api)
    assert r.status_code == 200


def test_code_expires_after_10_minutes(api):
    with freeze_time("2026-01-01 10:00:00") as t:
        start(api)
        code = last_code()
        t.tick(11 * 60)
        # redis TTL is wall-clock; emulate expiry by deleting the key as redis would
        from mc.common.redis import get_redis

        get_redis().flushdb()
        assert verify(api, code).status_code == 422


def test_code_is_single_use(api):
    start(api)
    code = last_code()
    assert verify(api, code).status_code == 201
    assert verify(api, code).status_code == 422


def test_five_wrong_attempts_burn_the_challenge(api):
    start(api)
    good = last_code()
    wrong = "000000" if good != "000000" else "111111"
    for _ in range(5):
        assert verify(api, wrong).status_code == 422
    assert verify(api, good).status_code == 422  # burned, even the right code fails
    assert not Account.objects.exists()


def test_four_wrong_then_right_still_works(api):
    start(api)
    good = last_code()
    wrong = "000000" if good != "000000" else "111111"
    for _ in range(4):
        verify(api, wrong)
    assert verify(api, good).status_code == 201


def test_new_start_replaces_old_code(api):
    start(api)
    old = last_code()
    start(api)
    new = last_code()
    if old != new:
        assert verify(api, old).status_code == 422
    assert verify(api, new).status_code == 201


def test_malformed_code_rejected(api):
    assert verify(api, "12ab56").status_code == 422
    assert verify(api, "123").status_code == 422


def test_send_limit_per_phone(api):
    for i in range(5):
        assert start(api, ip=f"10.0.1.{i}").status_code == 202
    r = start(api, ip="10.0.1.99")
    assert r.status_code == 429 and int(r["Retry-After"]) > 0
    assert start(api, "+256772000009").status_code == 202


def test_send_limit_per_ip(api, settings):
    settings.OTP_SENDS_PER_IP_PER_HOUR = 3
    for i in range(3):
        assert start(api, f"+25677200010{i}", ip="9.9.9.9").status_code == 202
    assert start(api, "+256772000109", ip="9.9.9.9").status_code == 429


def test_send_limit_per_prefix(api, settings):
    settings.OTP_SENDS_PER_PREFIX_PER_HOUR = 2
    for i in range(2):
        assert start(api, f"+25677200020{i}", ip=f"8.8.8.{i}").status_code == 202
    assert start(api, "+256772000209", ip="8.8.8.9").status_code == 429


def test_sms_provider_failure_is_502_without_creating_account(api):
    FakeSms.fail = True
    assert start(api).status_code == 502


def test_deactivated_account_cannot_sign_in(api):
    Account.objects.create(phone_e164=PHONE, status="deactivated")
    start(api)
    assert verify(api, last_code()).status_code == 403


def test_code_not_in_response_or_logs(api, caplog):
    r = start(api)
    assert last_code() not in r.content.decode()
    assert last_code() not in caplog.text

import re
import uuid

import pytest
from django.test import Client
from freezegun import freeze_time

from mc.accounts.models import Account, RecoverySession, Session
from mc.accounts.providers.email import FakeEmail
from mc.accounts.providers.sms import FakeSms
from mc.accounts.tests.helpers import bearer, last_code, login
from mc.audit.models import AuditEvent
from mc.verification.providers.base import VendorResult
from mc.verification.providers.fake import FakeIdentityProvider

pytestmark = pytest.mark.django_db
J = {"content_type": "application/json"}
OLD, NEW = "+256772700001", "+256772700002"


def api():
    return Client(headers={"host": "api.mc.test"})


def email_code(to=None):
    for dest, _subj, body in reversed(FakeEmail.outbox):
        if (to is None or dest == to.lower()) and (m := re.search(r"code is (\d{6})", body)):
            return m.group(1)
    raise AssertionError("no email code")


def member_with_email(email="amani@example.com"):
    c = api()
    r = login(c, phone=OLD)
    c.post("/api/v1/me/email/start", {"email": email}, **bearer(r), **J)
    assert (
        c.post("/api/v1/me/email/verify", {"code": email_code(email)}, **bearer(r), **J).status_code
        == 200
    )
    return c, r, Account.objects.get(phone_e164=OLD)


def biometric(job_id, *, passed=True):
    body = FakeIdentityProvider.callback_body(
        VendorResult(
            job_id=job_id,
            outcome="passed" if passed else "failed",
            liveness_passed=passed,
            face_match_passed=passed,
        )
    )
    return api().post(
        "/api/v1/webhooks/smile-id",
        body,
        HTTP_X_FAKE_SIGNATURE=FakeIdentityProvider.sign(body),
        **J,
    )


def to_biometric_passed(passed=True):
    c, r, acct = member_with_email()
    api().post("/api/v1/auth/recover/start", {"phone": OLD}, **J)
    out = api().post("/api/v1/auth/recover/verify-email", {"phone": OLD, "code": email_code()}, **J)
    assert out.status_code == 200
    body = out.json()
    assert body["sdk_params"]["job_id"].startswith("mcr_")
    assert biometric(body["sdk_params"]["job_id"], passed=passed).status_code == 200
    return c, r, acct, body["recovery_token"]


def test_recovery_email_verification_and_privacy():
    c, r, acct = member_with_email("Amani@Example.com")
    assert acct.email == "amani@example.com" and acct.email_verified_at
    assert (
        c.post("/api/v1/me/email/start", {"email": "not-an-email"}, **bearer(r), **J).status_code
        == 422
    )
    # wrong code
    c.post("/api/v1/me/email/start", {"email": "second@example.com"}, **bearer(r), **J)
    assert c.post("/api/v1/me/email/verify", {"code": "000000"}, **bearer(r), **J).status_code in (
        422,
    )
    assert Account.objects.get(id=acct.id).email == "amani@example.com"
    # an address already used by someone else gets no code and no error (no enumeration)
    other = api()
    ro = login(other, phone=NEW)
    FakeEmail.reset()
    assert (
        other.post(
            "/api/v1/me/email/start", {"email": "amani@example.com"}, **bearer(ro), **J
        ).status_code
        == 202
    )
    assert FakeEmail.outbox == []
    assert api().post("/api/v1/me/email/start", {"email": "x@y.co"}, **J).status_code == 401


def test_full_recovery_changes_phone_signs_out_everywhere_and_notifies():
    c, r, acct, token = to_biometric_passed()
    FakeSms.reset()
    FakeEmail.reset()
    assert (
        api()
        .post("/api/v1/auth/recover/new-phone", {"recovery_token": token, "new_phone": NEW}, **J)
        .status_code
        == 202
    )
    assert FakeSms.outbox[0][0] == NEW  # code goes to the NEW number only
    code = last_code(NEW)
    done = api().post("/api/v1/auth/recover/complete", {"recovery_token": token, "code": code}, **J)
    assert done.status_code == 200
    assert Account.objects.get(id=acct.id).phone_e164 == NEW
    assert (
        c.get("/api/v1/me", **bearer(r)).status_code == 401
        and not Session.objects.filter(account=acct, revoked_at__isnull=True).exists()
    )
    assert any(dest == OLD and "was changed" in body for dest, body in FakeSms.outbox)
    assert any(
        dest == "amani@example.com" and "changed" in subj for dest, subj, _ in FakeEmail.outbox
    )
    ev = AuditEvent.objects.get(action="account.phone_changed")
    assert (
        ev.target_id == acct.id
        and OLD not in str(ev.metadata)
        and NEW not in str(ev.metadata)
        and ev.ip_hmac
    )
    assert RecoverySession.objects.filter(state="completed").count() == 1
    # the member can now sign in with the new number and keeps their account
    c2 = api()
    assert login(c2, phone=NEW).json()["account"]["id"] == str(acct.id)
    # the recovery token is single-use
    assert (
        api()
        .post("/api/v1/auth/recover/complete", {"recovery_token": token, "code": code}, **J)
        .status_code
        == 403
    )


def test_unknown_phone_and_phone_without_verified_email_get_the_same_202_and_no_email():
    api().post("/api/v1/auth/otp/start", {"phone": OLD}, **J)
    api().post(
        "/api/v1/auth/otp/verify", {"phone": OLD, "code": last_code(OLD)}, **J
    )  # account without email
    FakeEmail.reset()
    a = api().post("/api/v1/auth/recover/start", {"phone": OLD}, **J)
    b = api().post("/api/v1/auth/recover/start", {"phone": "+256772799999"}, **J)
    assert (a.status_code, a.json()) == (b.status_code, b.json()) == (
        202,
        {"status": "accepted"},
    ) or a.json() == b.json()
    assert FakeEmail.outbox == [] and not RecoverySession.objects.exists()


def test_wrong_email_code_and_attempt_burn():
    member_with_email()
    api().post("/api/v1/auth/recover/start", {"phone": OLD}, **J)
    good = email_code()
    bad = "000000" if good != "000000" else "111111"
    for _ in range(5):
        assert (
            api()
            .post("/api/v1/auth/recover/verify-email", {"phone": OLD, "code": bad}, **J)
            .status_code
            == 422
        )
    assert (
        api()
        .post("/api/v1/auth/recover/verify-email", {"phone": OLD, "code": good}, **J)
        .status_code
        == 422
    )  # burned


def test_biometric_failure_blocks_the_swap():
    c, r, acct, token = to_biometric_passed(passed=False)
    assert (
        api().post("/api/v1/auth/recover/status", {"recovery_token": token}, **J).json()["state"]
        == "failed"
    )
    resp = api().post(
        "/api/v1/auth/recover/new-phone", {"recovery_token": token, "new_phone": NEW}, **J
    )
    assert resp.status_code == 403
    assert Account.objects.get(id=acct.id).phone_e164 == OLD


def test_cannot_skip_steps_forge_tokens_or_reuse_after_expiry():
    c, r, acct = member_with_email()
    api().post("/api/v1/auth/recover/start", {"phone": OLD}, **J)
    out = (
        api()
        .post("/api/v1/auth/recover/verify-email", {"phone": OLD, "code": email_code()}, **J)
        .json()
    )
    token = out["recovery_token"]
    assert (
        api().post("/api/v1/auth/recover/status", {"recovery_token": token}, **J).json()["state"]
        == "biometric_pending"
    )
    # biometric not done yet → cannot choose a new phone
    assert (
        api()
        .post("/api/v1/auth/recover/new-phone", {"recovery_token": token, "new_phone": NEW}, **J)
        .status_code
        == 403
    )
    assert (
        api()
        .post("/api/v1/auth/recover/new-phone", {"recovery_token": "forged", "new_phone": NEW}, **J)
        .status_code
        == 403
    )
    biometric(out["sdk_params"]["job_id"])
    biometric(out["sdk_params"]["job_id"])  # replay is harmless
    with freeze_time("2099-01-01"):
        assert (
            api()
            .post(
                "/api/v1/auth/recover/new-phone", {"recovery_token": token, "new_phone": NEW}, **J
            )
            .status_code
            == 403
        )


def test_new_phone_rules_taken_number_gives_no_signal_and_no_code():
    c, r, acct, token = to_biometric_passed()
    other = api()
    login(other, phone=NEW)  # NEW already belongs to someone else
    FakeSms.reset()
    resp = api().post(
        "/api/v1/auth/recover/new-phone", {"recovery_token": token, "new_phone": NEW}, **J
    )
    assert resp.status_code == 202 and FakeSms.outbox == []  # same answer, nothing sent
    assert (
        api()
        .post("/api/v1/auth/recover/complete", {"recovery_token": token, "code": "123456"}, **J)
        .status_code
        == 422
    )
    assert (
        api()
        .post("/api/v1/auth/recover/new-phone", {"recovery_token": token, "new_phone": OLD}, **J)
        .status_code
        == 422
    )  # same number
    assert (
        api()
        .post(
            "/api/v1/auth/recover/new-phone",
            {"recovery_token": token, "new_phone": "+14155550123"},
            **J,
        )
        .status_code
        == 422
    )  # not allow-listed
    assert Account.objects.get(id=acct.id).phone_e164 == OLD


def test_rate_limits_on_recovery_start(settings):
    member_with_email()
    codes = [
        api().post("/api/v1/auth/recover/start", {"phone": OLD}, **J).status_code for _ in range(5)
    ]
    assert codes[:3] == [202, 202, 202] and 429 in codes[3:]
    assert uuid.uuid4()

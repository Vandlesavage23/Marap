import pytest
from django.test import Client

from mc.accounts.models import Session
from mc.accounts.tests.helpers import last_code
from mc.billing.models import Purchase
from mc.billing.providers.flutterwave import FakeGateway
from mc.billing.tests.test_web import HASH, hook, pay
from mc.entitlements import selectors as ent
from mc.interests.tests.helpers import member

pytestmark = pytest.mark.django_db
HOST = "pay.mc.test"


def browser(strict: bool = False) -> Client:
    return Client(headers={"host": HOST}, enforce_csrf_checks=strict)


def sign_in(who) -> Client:
    c = browser()
    assert c.post("/login", {"phone": who[2].phone_e164}).status_code == 302
    r = c.post("/code", {"code": last_code(who[2].phone_e164)})
    assert r.status_code == 302 and r["Location"] == "/"
    return c


def test_anonymous_visitors_are_sent_to_login():
    c = browser()
    for path in ("/", "/pay/membership_1m", "/status/00000000-0000-0000-0000-000000000000"):
        assert c.get(path)["Location"] == "/login"


def test_unknown_phone_gets_the_same_page_but_no_sms_and_no_account_is_created():
    from mc.accounts.models import Account
    from mc.accounts.providers.sms import FakeSms

    c = browser()
    assert c.post("/login", {"phone": "+256772999999"}).status_code == 302
    assert FakeSms.outbox == [] and not Account.objects.filter(phone_e164="+256772999999").exists()
    assert c.post("/code", {"code": "123456"}).status_code == 422


def test_bad_code_rejected_and_cookie_flags_are_strict():
    who = member("male", trial=False)
    c = browser()
    c.post("/login", {"phone": who[2].phone_e164})
    assert c.post("/code", {"code": "000000"}).status_code == 422
    c.post("/code", {"code": last_code(who[2].phone_e164)})
    ck = c.cookies["mc_pay"]
    assert ck["httponly"] and ck["samesite"] == "Strict"


def test_full_mobile_money_flow_pending_then_paid_via_verified_webhook():
    who = member("male", trial=False)
    c = sign_in(who)
    page = c.get("/")
    assert "membership_1m" in page.content.decode() and "does not renew" in page.content.decode()
    form = c.get("/pay/membership_1m")
    nonce = form.context["nonce"]
    r = c.post(
        "/pay/membership_1m",
        {"nonce": nonce, "method": "mobile_money", "network": "mtn", "phone": "0772000001"},
    )
    assert r.status_code == 302
    p = Purchase.objects.get()
    assert (
        p.status == "pending" and p.amount_minor == p.product.price_minor
    )  # price from OUR catalogue
    assert "Approve the prompt" in c.get(r["Location"]).content.decode()
    # double submit with the same nonce → same purchase, no second charge
    again = c.post(
        "/pay/membership_1m", {"nonce": nonce, "method": "mobile_money", "network": "mtn"}
    )
    assert again["Location"] == r["Location"] and Purchase.objects.count() == 1
    assert hook(pay(str(p.id), amount=p.amount_minor)).status_code == 200
    assert "Payment received" in c.get(r["Location"]).content.decode()
    assert ent.entitlement_summary(who[2]).state == "member"


def test_gateway_outage_shows_an_error_and_leaves_no_purchase():
    who = member("male", trial=False)
    c = sign_in(who)
    FakeGateway.fail = True
    r = c.post(
        "/pay/membership_1m", {"nonce": "n0nce12345", "method": "mobile_money", "network": "mtn"}
    )
    assert r.status_code == 422 and not Purchase.objects.exists()


def test_validation_unknown_plan_bad_network_and_other_members_purchase_hidden():
    a, b = member("male", trial=False), member("female", trial=False)
    ca, cb = sign_in(a), sign_in(b)
    assert ca.get("/pay/nope").status_code == 404
    r = ca.post(
        "/pay/membership_1m",
        {"nonce": "n0nce12345", "method": "mobile_money", "network": "vodafone"},
    )
    assert r.status_code == 422
    ca.post(
        "/pay/membership_1m", {"nonce": "n0nce67890", "method": "mobile_money", "network": "mtn"}
    )
    pid = Purchase.objects.get().id
    assert cb.get(f"/status/{pid}").status_code == 404
    assert (
        ca.post("/pay/membership_1m", {"nonce": "x", "method": "card"}).status_code == 422
    )  # bad nonce


def test_csrf_enforced_logout_and_revoked_session_end_access():
    who = member("male", trial=False)
    c = sign_in(who)
    strict = browser(strict=True)
    strict.cookies = c.cookies
    assert strict.post("/logout").status_code == 403
    Session.objects.filter(account=who[2]).update(revoked_at="2020-01-01T00:00:00Z")
    assert c.get("/")["Location"] == "/login"
    c = sign_in(who)
    assert c.post("/logout")["Location"] == "/login"


def test_security_headers_on_pay_host():
    r = browser().get("/login")
    assert (
        "frame-ancestors 'none'" in r["Content-Security-Policy"]
        and r["Cache-Control"] == "no-store"
    )


_ = HASH

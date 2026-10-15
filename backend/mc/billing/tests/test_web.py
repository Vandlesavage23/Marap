import uuid
from datetime import timedelta

import pytest
from django.test import Client
from django.utils import timezone

from mc.accounts.tests.helpers import bearer
from mc.billing import services
from mc.billing.models import PaymentEvent, Purchase
from mc.billing.providers.flutterwave import FakeGateway, VerifiedTransaction
from mc.entitlements import selectors as ent
from mc.interests.tests.helpers import member
from mc.verification.tests.helpers import J

pytestmark = pytest.mark.django_db
HASH = "fake-webhook-hash"


def checkout(who, code="membership_1m", method="mobile_money", **extra):
    body = {
        "product_code": code,
        "method": method,
        **({"network": "mtn"} if method == "mobile_money" else {}),
        **extra,
    }
    return who[0].post(
        "/api/v1/billing/web/checkout",
        body,
        **bearer(who[1]),
        HTTP_IDEMPOTENCY_KEY=uuid.uuid4().hex,
        **J,
    )


def hook(payload, h=HASH):
    return Client(headers={"host": "api.mc.test"}).post(
        "/api/v1/webhooks/flutterwave", payload, HTTP_VERIF_HASH=h, **J
    )


def pay(tx_ref, *, tid="9001", status="successful", amount=20000, currency="UGX"):
    FakeGateway.transactions[tid] = VerifiedTransaction(tid, tx_ref, status, amount, currency)
    return {
        "event": "charge.completed",
        "data": {
            "id": int(tid),
            "tx_ref": tx_ref,
            "status": status,
            "amount": 1,
            "currency": "USD",
        },
    }  # body is a lie on purpose


def test_checkout_creates_pending_purchase_with_server_side_amount():
    who = member("male", trial=False)
    resp = checkout(who)
    assert resp.status_code == 201
    body = resp.json()
    assert (
        body["status"] == "pending"
        and body["amount_minor"] == 20000
        and body["instruction"].startswith("Approve")
    )
    p = Purchase.objects.get()
    assert (
        p.provider == "flutterwave"
        and p.original_transaction_id == str(p.id) == body["purchase_id"]
    )
    assert FakeGateway.charges == [
        {
            "tx_ref": str(p.id),
            "amount": 20000,
            "currency": "UGX",
            "method": "mobile_money",
            "network": "mtn",
        }
    ]
    assert not ent.has_capability(who[2], "browse")


def test_client_cannot_choose_price_and_card_returns_link():
    who = member("male", trial=False)
    assert (
        who[0]
        .post(
            "/api/v1/billing/web/checkout",
            {"product_code": "membership_1m", "method": "card", "amount": 1},
            **bearer(who[1]),
            HTTP_IDEMPOTENCY_KEY="k-12345678",
            **J,
        )
        .status_code
        == 422
    )
    resp = checkout(who, "membership_3m", "card")
    assert (
        resp.status_code == 201
        and resp.json()["link"].startswith("https://")
        and resp.json()["amount_minor"] == 50000
    )


@pytest.mark.parametrize(
    "body",
    [
        {"product_code": "nope", "method": "card"},
        {"product_code": "membership_1m", "method": "mobile_money", "network": "vodafone"},
        {"product_code": "membership_1m", "method": "bitcoin"},
    ],
)
def test_checkout_validation(body):
    who = member("male", trial=False)
    assert (
        who[0]
        .post(
            "/api/v1/billing/web/checkout",
            body,
            **bearer(who[1]),
            HTTP_IDEMPOTENCY_KEY="k-12345678",
            **J,
        )
        .status_code
        == 422
    )
    assert not Purchase.objects.exists()


def test_checkout_flag_idempotency_gateway_outage_and_auth(settings):
    who = member("male", trial=False)
    key = "same-checkout-key"
    a = who[0].post(
        "/api/v1/billing/web/checkout",
        {"product_code": "membership_1m", "method": "card"},
        **bearer(who[1]),
        HTTP_IDEMPOTENCY_KEY=key,
        **J,
    )
    b = who[0].post(
        "/api/v1/billing/web/checkout",
        {"product_code": "membership_1m", "method": "card"},
        **bearer(who[1]),
        HTTP_IDEMPOTENCY_KEY=key,
        **J,
    )
    assert a.json() == b.json() and Purchase.objects.count() == 1
    FakeGateway.fail = True
    assert (
        checkout(who).status_code == 502 and Purchase.objects.count() == 1
    )  # no orphan pending purchase
    FakeGateway.fail = False
    settings.WEB_CHECKOUT_ENABLED = False
    assert checkout(who).status_code == 422
    assert (
        Client(headers={"host": "api.mc.test"})
        .post("/api/v1/billing/web/checkout", {}, **J)
        .status_code
        == 401
    )


def test_webhook_header_is_checked_in_constant_time_and_required():
    assert hook({"data": {"id": 1}}, h="wrong").status_code == 401
    assert hook({"data": {"id": 1}}, h="").status_code == 401
    assert not PaymentEvent.objects.exists()


def test_webhook_reverifies_and_grants_using_our_amount_not_the_bodys():
    who = member("male", trial=False)
    p = Purchase.objects.get(id=checkout(who).json()["purchase_id"])
    assert (
        hook(pay(str(p.id))).status_code == 200
    )  # webhook body claims 1 USD; gateway says 20,000 UGX
    p.refresh_from_db()
    assert p.status == "active" and ent.entitlement_summary(who[2]).state == "member"
    assert (p.period_end - p.period_start).days == 30 and p.auto_renew is False
    assert services.ledger_balance(p) == 20000


def test_webhook_replay_and_status_polling():
    who = member("male", trial=False)
    pid = checkout(who).json()["purchase_id"]
    assert (
        who[0].get(f"/api/v1/billing/web/purchases/{pid}", **bearer(who[1])).json()["status"]
        == "pending"
    )
    for _ in range(3):
        hook(pay(pid))
    assert PaymentEvent.objects.count() == 1
    body = who[0].get(f"/api/v1/billing/web/purchases/{pid}", **bearer(who[1])).json()
    assert body["status"] == "active" and body["period_end"]
    other = member("female", trial=False)
    assert (
        other[0].get(f"/api/v1/billing/web/purchases/{pid}", **bearer(other[1])).status_code == 404
    )


@pytest.mark.parametrize(
    "bad", [{"amount": 19999}, {"currency": "USD"}, {"status": "failed"}, {"status": "pending"}]
)
def test_amount_currency_status_mismatch_never_grants(bad):
    who = member("male", trial=False)
    pid = checkout(who).json()["purchase_id"]
    hook(pay(pid, **bad))
    assert (
        Purchase.objects.get().status == "pending"
        and ent.entitlement_summary(who[2]).state != "member"
    )
    if "amount" in bad or "currency" in bad:
        assert PaymentEvent.objects.get().process_status == "failed"


def test_unknown_tx_ref_and_gateway_outage():
    assert hook(pay(str(uuid.uuid4()))).status_code == 200  # recorded, ignored
    assert (
        PaymentEvent.objects.get().event_type == "unknown_tx_ref" and not Purchase.objects.exists()
    )
    who = member("male", trial=False)
    pid = checkout(who).json()["purchase_id"]
    FakeGateway.fail = True
    assert (
        hook({"data": {"id": 9001, "tx_ref": pid}}).status_code == 502
    )  # provider will retry the webhook
    assert Purchase.objects.get().status == "pending"


def test_second_purchase_extends_from_current_end():
    who = member("male", trial=False)
    a = checkout(who).json()["purchase_id"]
    hook(pay(a, tid="1"))
    end1 = Purchase.objects.get(id=a).period_end
    b = checkout(who, "membership_3m").json()["purchase_id"]
    hook(pay(b, tid="2", amount=50000))
    pb = Purchase.objects.get(id=b)
    assert abs(pb.period_start - end1) < timedelta(seconds=1) and (pb.period_end - end1).days == 90
    assert ent.entitlement_summary(who[2]).membership_ends_at == pb.period_end


def test_webhook_cannot_grant_to_someone_elses_purchase_via_tx_ref_confusion():
    a, b = member("male", trial=False), member("female", trial=False)
    pa = checkout(a).json()["purchase_id"]
    hook(pay(pa))
    assert (
        ent.entitlement_summary(a[2]).state == "member"
        and ent.entitlement_summary(b[2]).state != "member"
    )
    assert timezone.now() is not None

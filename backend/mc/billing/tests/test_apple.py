import uuid
from datetime import UTC, datetime, timedelta

import pytest
from django.test import Client

from mc.accounts.tests.helpers import bearer
from mc.billing import services
from mc.billing.models import PaymentEvent, Purchase
from mc.entitlements import selectors as ent
from mc.interests.tests.helpers import member
from mc.verification.tests.helpers import J

from .apple_helpers import FakeApplePki, notification_payload, transaction_payload

pytestmark = pytest.mark.django_db


@pytest.fixture
def pki(settings):
    p = FakeApplePki()
    settings.APPLE_ROOT_CERTS_PEM = [p.root_pem]
    return p


def verify(who, signed, key=None):
    return who[0].post(
        "/api/v1/billing/store/verify",
        {"platform": "ios", "signed_transaction": signed},
        **bearer(who[1]),
        HTTP_IDEMPOTENCY_KEY=key or uuid.uuid4().hex,
        **J,
    )


def webhook(client, signed):
    return client.post("/api/v1/webhooks/apple", {"signedPayload": signed}, **J)


def anon():
    return Client(headers={"host": "api.mc.test"})


def test_verify_grants_membership_and_binds_to_account(pki):
    who = member("male", trial=False)
    resp = verify(who, pki.sign(transaction_payload(account_id=who[2].id)))
    assert resp.status_code == 200
    body = resp.json()
    assert body["state"] == "member" and body["capabilities"]["send_interest"] is True
    p = Purchase.objects.get()
    assert (
        p.provider == "apple"
        and p.status == "active"
        and p.account_id == who[2].id
        and p.auto_renew is True
    )
    assert (p.period_end - p.period_start).days == 30
    assert ent.entitlement_summary(who[2]).state == "member"


def test_verify_is_idempotent_and_restore_returns_same_purchase(pki):
    who = member("male", trial=False)
    signed = pki.sign(transaction_payload(account_id=who[2].id, txn="42"))
    verify(who, signed)
    verify(who, signed)  # "restore purchases" replays the same transaction
    assert Purchase.objects.count() == 1 and PaymentEvent.objects.count() == 1


def test_purchase_for_another_account_is_refused(pki):
    a, b = member("male", trial=False), member("female", trial=False)
    signed = pki.sign(transaction_payload(account_id=a[2].id))
    resp = verify(b, signed)  # b replays a's receipt
    assert resp.status_code == 403 and not Purchase.objects.exists()
    missing = pki.sign(transaction_payload(account_id=a[2].id, token=None))
    assert verify(a, missing).status_code == 403  # no appAccountToken → can't bind


@pytest.mark.parametrize(
    "patch", [{"bundleId": "com.evil.app"}, {"environment": "Production"}, {"productId": "nope"}]
)
def test_wrong_bundle_environment_or_product_rejected(pki, patch):
    who = member("male", trial=False)
    resp = verify(who, pki.sign(transaction_payload(account_id=who[2].id, **patch)))
    assert resp.status_code == 422 and not Purchase.objects.exists()


def test_untrusted_expired_and_tampered_signatures_rejected(pki, settings):
    who = member("male", trial=False)
    payload = transaction_payload(account_id=who[2].id)
    other_pki = FakeApplePki()  # attacker's own CA
    assert verify(who, other_pki.sign(payload)).status_code == 422
    expired = FakeApplePki(leaf_days=1, leaf_start=datetime.now(UTC) - timedelta(days=30))
    settings.APPLE_ROOT_CERTS_PEM = [expired.root_pem]
    assert verify(who, expired.sign(payload)).status_code == 422
    settings.APPLE_ROOT_CERTS_PEM = [pki.root_pem]
    good = pki.sign(payload)
    head, body, sig = good.split(".")
    tampered = ".".join([head, body[:-4] + ("AAAA" if body[-4:] != "AAAA" else "BBBB"), sig])
    assert verify(who, tampered).status_code == 422
    assert verify(who, "not.a.jws").status_code == 422
    assert (
        verify(who, pki.sign(payload, chain=[pki.leaf])).status_code == 422
    )  # missing intermediate → chain breaks
    settings.APPLE_ROOT_CERTS_PEM = []
    assert verify(who, good).status_code in (502, 422)  # misconfiguration fails closed
    assert not Purchase.objects.exists()


def test_validation_and_auth():
    who = member("male", trial=False)
    assert (
        who[0]
        .post(
            "/api/v1/billing/store/verify",
            {"platform": "ios"},
            **bearer(who[1]),
            HTTP_IDEMPOTENCY_KEY="k-12345678",
            **J,
        )
        .status_code
        == 422
    )
    assert anon().post("/api/v1/billing/store/verify", {}, **J).status_code == 401
    assert (
        who[0]
        .post(
            "/api/v1/billing/store/verify",
            {"platform": "ios", "signed_transaction": "x"},
            **bearer(who[1]),
            **J,
        )
        .status_code
        == 422
    )  # no idempotency key


def test_products_for_each_platform():
    who = member("male", trial=False)
    ios = who[0].get("/api/v1/billing/products?platform=ios", **bearer(who[1])).json()["items"]
    android = (
        who[0].get("/api/v1/billing/products?platform=android", **bearer(who[1])).json()["items"]
    )
    assert (
        [p["code"] for p in ios]
        == ["membership_1m", "membership_3m"]
        == [p["code"] for p in android]
    )
    assert (
        ios[0]["store_product_id"].startswith("ug.marriageconnect.")
        and ios[0]["price_minor"] == 20000
    )
    assert (
        "web" not in str([ios, android]).lower()
        and who[0].get("/api/v1/billing/products?platform=web", **bearer(who[1])).status_code == 422
    )


# ---- Server Notifications v2 ------------------------------------------------------------------------
def test_notification_signature_required():
    assert webhook(anon(), "garbage").status_code == 422
    assert anon().post("/api/v1/webhooks/apple", {}, **J).status_code == 422


def test_scenario_05_client_loses_confirmation_webhook_still_grants(pki):
    """Payment succeeds, the app never calls /billing/store/verify (network loss) → the notification grants access."""
    who = member("male", trial=False)
    txn = transaction_payload(account_id=who[2].id)
    assert ent.entitlement_summary(who[2]).state in ("none", "expired")
    resp = webhook(
        anon(),
        notification_payload(pki, ntype="SUBSCRIBED", subtype="INITIAL_BUY", txn_payload=txn),
    )
    assert resp.status_code == 200
    assert (
        Purchase.objects.get().status == "active"
        and ent.entitlement_summary(who[2]).state == "member"
    )
    # and the app's later "restore/verify" is a harmless no-op
    verify(who, pki.sign(txn))
    assert Purchase.objects.count() == 1 and Purchase.objects.get().status == "active"


def test_webhook_replay_is_idempotent(pki):
    who = member("male", trial=False)
    signed = notification_payload(
        pki,
        ntype="SUBSCRIBED",
        subtype="INITIAL_BUY",
        txn_payload=transaction_payload(account_id=who[2].id),
        uuid_="n-1",
    )
    for _ in range(3):
        assert webhook(anon(), signed).status_code == 200
    assert PaymentEvent.objects.count() == 1 and Purchase.objects.count() == 1
    from mc.entitlements.models import Entitlement

    assert Entitlement.objects.count() == 1


def test_renewal_cancel_expire_flow(pki):
    who = member("male", trial=False)
    t0 = datetime.now(UTC) - timedelta(days=5)
    first = transaction_payload(account_id=who[2].id, purchase=t0, txn="1")
    renew = transaction_payload(account_id=who[2].id, purchase=t0 + timedelta(days=30), txn="2")
    webhook(anon(), notification_payload(pki, ntype="SUBSCRIBED", txn_payload=first, signed_at=t0))
    webhook(
        anon(),
        notification_payload(
            pki,
            ntype="DID_CHANGE_RENEWAL_STATUS",
            subtype="AUTO_RENEW_DISABLED",
            txn_payload=first,
            signed_at=t0 + timedelta(days=1),
        ),
    )
    p = Purchase.objects.get()
    assert p.auto_renew is False and p.status == "active"
    webhook(
        anon(),
        notification_payload(
            pki, ntype="DID_RENEW", txn_payload=renew, signed_at=t0 + timedelta(days=30)
        ),
    )
    p.refresh_from_db()
    assert p.period_end == datetime.fromtimestamp(int(renew["expiresDate"]) / 1000, tz=UTC)
    webhook(
        anon(), notification_payload(pki, ntype="EXPIRED", subtype="VOLUNTARY", txn_payload=renew)
    )
    assert PaymentEvent.objects.filter(event_type__startswith="EXPIRED").exists()


def test_scenario_07_refund_after_activation_revokes_and_balances(pki):
    who = member("male", trial=False)
    txn = transaction_payload(account_id=who[2].id)
    verify(who, pki.sign(txn))
    assert ent.entitlement_summary(who[2]).state == "member"
    resp = webhook(
        anon(),
        notification_payload(
            pki,
            ntype="REFUND",
            txn_payload={**txn, "revocationDate": txn["purchaseDate"] + 1000},
            signed_at=datetime.now(UTC) + timedelta(seconds=5),
        ),
    )
    assert resp.status_code == 200
    p = Purchase.objects.get()
    assert p.status == "refunded" and services.ledger_balance(p) == 0
    assert ent.entitlement_summary(who[2]).state != "member" and not ent.has_capability(
        who[2],
        "higher_interest_cap",  # v2: a refund ends the membership perks (free sending stays)
    )
    # a refund replay or late renewal event changes nothing
    webhook(anon(), notification_payload(pki, ntype="REFUND", txn_payload=txn, uuid_="again"))
    assert Purchase.objects.get().status == "refunded"


def test_informational_notifications_are_stored_and_ignored(pki):
    who = member("male", trial=False)
    resp = webhook(
        anon(),
        notification_payload(
            pki,
            ntype="DID_FAIL_TO_RENEW",
            subtype="GRACE_PERIOD",
            txn_payload=transaction_payload(account_id=who[2].id),
        ),
    )
    assert resp.status_code == 200
    ev = PaymentEvent.objects.get()
    assert ev.process_status == "ignored" and not Purchase.objects.exists()


def test_verify_a_revoked_transaction_ends_in_refunded(pki):
    who = member("male", trial=False)
    now = datetime.now(UTC)
    verify(
        who,
        pki.sign(
            transaction_payload(
                account_id=who[2].id,
                revoked=now - timedelta(minutes=1),
                purchase=now - timedelta(days=1),
            )
        ),
    )
    assert Purchase.objects.get().status == "refunded"
    assert ent.entitlement_summary(who[2]).state != "member"

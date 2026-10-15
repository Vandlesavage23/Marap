import base64
import json
import uuid
from datetime import UTC, datetime, timedelta

import jwt
import pytest
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from django.test import Client

from mc.accounts.tests.helpers import bearer
from mc.billing import services
from mc.billing.models import PaymentEvent, Purchase
from mc.billing.providers import google
from mc.billing.providers.google import FakePlayApi
from mc.entitlements import selectors as ent
from mc.interests.tests.helpers import member
from mc.verification.tests.helpers import J

pytestmark = pytest.mark.django_db
GPID = "membership_1m"


def sub(
    account_id,
    *,
    token="tok-abc",
    state="SUBSCRIPTION_STATE_ACTIVE",
    days=30,
    auto=True,
    ack="ACKNOWLEDGEMENT_STATE_PENDING",
    bound="default",
):
    expiry = (datetime.now(UTC) + timedelta(days=days)).strftime("%Y-%m-%dT%H:%M:%S.%fZ")
    res = {
        "startTime": (datetime.now(UTC) - timedelta(days=1)).strftime("%Y-%m-%dT%H:%M:%S.%fZ"),
        "subscriptionState": state,
        "latestOrderId": "GPA.1234-5678",
        "acknowledgementState": ack,
        "externalAccountIdentifiers": {
            "obfuscatedExternalAccountId": str(account_id) if bound == "default" else bound
        },
        "lineItems": [
            {
                "productId": GPID,
                "expiryTime": expiry,
                "autoRenewingPlan": {"autoRenewEnabled": auto},
            }
        ],
    }
    FakePlayApi.subscriptions[token] = res
    return res


def verify(who, token="tok-abc", product=GPID):
    return who[0].post(
        "/api/v1/billing/store/verify",
        {"platform": "android", "product_id": product, "purchase_token": token},
        **bearer(who[1]),
        HTTP_IDEMPOTENCY_KEY=uuid.uuid4().hex,
        **J,
    )


def test_verify_grants_acknowledges_and_stores_token_encrypted():
    who = member("male", trial=False)
    sub(who[2].id)
    resp = verify(who)
    assert resp.status_code == 200 and resp.json()["state"] == "member"
    p = Purchase.objects.get()
    assert (
        p.provider == "google"
        and p.status == "active"
        and p.provider_token == "tok-abc"
        and p.original_transaction_id == google.token_key("tok-abc")
    )
    assert FakePlayApi.acknowledged == ["tok-abc"]
    from django.db import connection

    with connection.cursor() as cur:
        cur.execute("SELECT provider_token FROM billing_purchase")
        assert cur.fetchone()[0].startswith("v1:")
    assert "tok-abc" not in str(PaymentEvent.objects.get().raw) and "tok-abc" not in str(
        PaymentEvent.objects.get().provider_event_id
    )


def test_already_acknowledged_purchase_is_not_acknowledged_again_and_verify_is_idempotent():
    who = member("male", trial=False)
    sub(who[2].id, ack="ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED")
    verify(who)
    verify(who)
    assert (
        FakePlayApi.acknowledged == []
        and Purchase.objects.count() == 1
        and PaymentEvent.objects.count() == 1
    )


def test_wrong_account_product_state_and_unknown_token_rejected():
    a, b = member("male", trial=False), member("female", trial=False)
    sub(a[2].id)
    assert verify(b).status_code == 403  # token bound to a different account
    assert verify(a, product="membership_3m").status_code == 422  # product mismatch
    sub(a[2].id, token="expired", state="SUBSCRIPTION_STATE_EXPIRED")
    assert verify(a, token="expired").status_code == 422
    assert verify(a, token="never-seen").status_code == 422
    sub(a[2].id, token="nobinding", bound="")
    assert verify(a, token="nobinding").status_code == 403
    assert not Purchase.objects.exists() and FakePlayApi.acknowledged == []


def test_play_outage_is_a_clean_502_and_nothing_is_granted():
    who = member("male", trial=False)
    sub(who[2].id)
    FakePlayApi.fail = True
    resp = verify(who)
    assert resp.status_code == 502 and resp.json()["code"] == "provider_error"
    assert not Purchase.objects.exists() and ent.entitlement_summary(who[2]).state != "member"
    FakePlayApi.fail = False
    assert verify(who).status_code == 200  # the retry succeeds


# ---- RTDN ---------------------------------------------------------------------------------------------
@pytest.fixture
def oidc(settings, monkeypatch):
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)

    class Jwks:
        def get_signing_key_from_jwt(self, token):
            class K:
                pass

            k = K()
            k.key = key.public_key()
            return k

    monkeypatch.setattr(google, "_default_jwks", lambda: Jwks())

    def mint(**over):
        claims = {
            "iss": "https://accounts.google.com",
            "aud": settings.GOOGLE_RTDN_AUDIENCE,
            "email": settings.GOOGLE_RTDN_SERVICE_ACCOUNT,
            "email_verified": True,
            "exp": int(datetime.now(UTC).timestamp()) + 600,
            "iat": int(datetime.now(UTC).timestamp()),
        }
        claims.update(over)
        pem = key.private_bytes(
            serialization.Encoding.PEM,
            serialization.PrivateFormat.PKCS8,
            serialization.NoEncryption(),
        )
        return "Bearer " + jwt.encode(claims, pem, algorithm="RS256")

    return mint


def push(auth, payload, message_id=None):
    body = {
        "message": {
            "data": base64.b64encode(json.dumps(payload).encode()).decode(),
            "messageId": message_id or str(uuid.uuid4()),
        },
        "subscription": "projects/x/subscriptions/y",
    }
    return Client(headers={"host": "api.mc.test"}).post(
        "/api/v1/webhooks/google", body, HTTP_AUTHORIZATION=auth, **J
    )


def note(token, ntype):
    return {"version": "1.0", "packageName": "ug.marriageconnect.app", "eventTimeMillis": "1",
            "subscriptionNotification": {"version": "1.0", "notificationType": ntype, "purchaseToken": token, "subscriptionId": GPID}}  # fmt: skip


def test_rtdn_oidc_authentication(oidc, settings):
    n = note("tok-abc", google.PURCHASED)
    assert push("", n).status_code == 401
    assert push("Bearer garbage", n).status_code == 401
    assert push(oidc(aud="https://evil.example"), n).status_code == 401
    assert push(oidc(email="attacker@evil.iam.gserviceaccount.com"), n).status_code == 401
    assert push(oidc(email_verified=False), n).status_code == 401
    assert push(oidc(iss="https://evil.example"), n).status_code == 401
    assert push(oidc(exp=1), n).status_code == 401
    settings.GOOGLE_RTDN_AUDIENCE = ""
    assert push(oidc(), n).status_code == 401  # unconfigured fails closed
    assert not PaymentEvent.objects.exists()


def test_scenario_05_google_client_loses_confirmation_rtdn_grants(oidc):
    who = member("male", trial=False)
    sub(who[2].id)
    resp = push(oidc(), note("tok-abc", google.PURCHASED))
    assert resp.status_code == 200
    assert (
        Purchase.objects.get().status == "active"
        and ent.entitlement_summary(who[2]).state == "member"
    )
    assert (
        FakePlayApi.acknowledged == ["tok-abc"]
        and Purchase.objects.get().provider_token == "tok-abc"
    )


def test_rtdn_replay_same_message_id_is_idempotent(oidc):
    who = member("male", trial=False)
    sub(who[2].id)
    for _ in range(3):
        assert push(oidc(), note("tok-abc", google.PURCHASED), message_id="m-1").status_code == 200
    assert PaymentEvent.objects.count() == 1 and Purchase.objects.count() == 1


def test_rtdn_cancel_renew_revoke_and_void(oidc):
    who = member("male", trial=False)
    sub(who[2].id, auto=True)
    push(oidc(), note("tok-abc", google.PURCHASED))
    sub(who[2].id, auto=False, state="SUBSCRIPTION_STATE_CANCELED")
    push(oidc(), note("tok-abc", google.CANCELED))
    p = Purchase.objects.get()
    assert p.auto_renew is False and p.status == "active"
    sub(who[2].id, days=60, auto=True)
    push(oidc(), note("tok-abc", google.RENEWED))
    p.refresh_from_db()
    assert p.status == "active" and (p.period_end - datetime.now(UTC)).days >= 59
    # voided purchase (refund) → access ends, ledger balances
    void = {"version": "1.0", "packageName": "ug.marriageconnect.app", "eventTimeMillis": "1",
            "voidedPurchaseNotification": {"purchaseToken": "tok-abc", "orderId": "GPA.1234-5678", "productType": 1, "refundType": 1}}  # fmt: skip
    assert push(oidc(), void).status_code == 200
    p.refresh_from_db()
    assert (p.status == "refunded" and services.ledger_balance(p) < 0) or services.ledger_balance(
        p
    ) == 0
    assert ent.entitlement_summary(who[2]).state != "member"


def test_rtdn_revoked_and_informational_types(oidc):
    who = member("male", trial=False)
    sub(who[2].id)
    push(oidc(), note("tok-abc", google.PURCHASED))
    sub(who[2].id, state="SUBSCRIPTION_STATE_ON_HOLD")
    assert push(oidc(), note("tok-abc", google.ON_HOLD)).status_code == 200
    assert PaymentEvent.objects.filter(event_type="rtdn:5").get().process_status == "ignored"
    assert push(oidc(), note("tok-abc", google.REVOKED)).status_code == 200
    assert (
        Purchase.objects.get().status == "revoked"
        and ent.entitlement_summary(who[2]).state != "member"
    )


def test_rtdn_for_other_app_test_notification_and_unknown_void(oidc):
    wrong = note("t", google.PURCHASED)
    wrong["packageName"] = "com.other.app"
    assert push(oidc(), wrong).status_code == 422
    test_n = {
        "version": "1.0",
        "packageName": "ug.marriageconnect.app",
        "eventTimeMillis": "1",
        "testNotification": {"version": "1.0"},
    }
    assert push(oidc(), test_n).status_code == 200
    void = {
        "version": "1.0",
        "packageName": "ug.marriageconnect.app",
        "eventTimeMillis": "1",
        "voidedPurchaseNotification": {"purchaseToken": "ghost", "orderId": "x"},
    }
    assert push(oidc(), void).status_code == 200
    assert not Purchase.objects.exists()
    assert (
        Client(headers={"host": "api.mc.test"})
        .post("/api/v1/webhooks/google", {"message": {}}, HTTP_AUTHORIZATION=oidc(), **J)
        .status_code
        == 422
    )

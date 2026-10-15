"""Store purchase intake: client-submitted proofs and store server notifications → ledger events (MC-098/099)."""

import json
import uuid
from datetime import UTC, datetime
from typing import TYPE_CHECKING, Any

from django.conf import settings

from mc.common.errors import Forbidden, NotFound, ValidationFailed

from . import services
from .events import CANCEL, GRANT, NormalizedEvent
from .models import PaymentEvent, Product, Purchase
from .providers import apple

if TYPE_CHECKING:
    from mc.accounts.models import Account


def _product_for_apple(product_id: str) -> Product:
    product = Product.objects.filter(apple_product_id=product_id, active=True).first()
    if product is None:
        raise ValidationFailed("Unknown product.")
    return product


def verify_apple_transaction(*, account: "Account", signed_transaction: str) -> Purchase:
    """`POST /billing/store/verify` (iOS): verify the JWS, bind it to the caller via appAccountToken, record the
    grant and process it now so the app can unlock immediately. Restore purchases uses the same path."""
    payload = apple.verify_jws(signed_transaction)
    txn = apple.parse_transaction(payload)
    if txn.account_token != account.id:
        raise Forbidden("This purchase belongs to a different account.")
    product = _product_for_apple(txn.product_id)
    now = datetime.now(UTC)
    event, _ = services.ingest_event(
        provider="apple",
        provider_event_id=f"txn:{txn.transaction_id}",
        event_type="client_verify",
        raw=_strip(payload),
        normalized=NormalizedEvent(
            kind=GRANT, provider="apple", transaction_id=txn.original_transaction_id, product_code=product.code,
            event_time=txn.purchase_date, account_id=account.id, period_start=txn.purchase_date,
            period_end=txn.expires_date, amount_minor=product.price_minor, currency=product.currency, auto_renew=True,
        ),
        signature_valid=True,
        account_id=account.id,
    )  # fmt: skip
    services.process_event(event_id=event.id)
    if txn.revocation_date:
        rev, _ = services.ingest_event(
            provider="apple", provider_event_id=f"rev:{txn.transaction_id}", event_type="client_verify_revoked",
            raw=_strip(payload),
            normalized=NormalizedEvent(kind="refund", provider="apple", transaction_id=txn.original_transaction_id,
                                       product_code=product.code, event_time=txn.revocation_date, account_id=account.id,
                                       amount_minor=product.price_minor, currency=product.currency),
            signature_valid=True, account_id=account.id,
        )  # fmt: skip
        services.process_event(event_id=rev.id)
    _ = now
    purchase = Purchase.objects.filter(
        provider="apple", original_transaction_id=txn.original_transaction_id
    ).first()
    if purchase is None:
        raise NotFound()
    return purchase


def handle_apple_notification(*, signed_payload: str) -> PaymentEvent:
    """`POST /webhooks/apple`: App Store Server Notifications v2. Unverifiable payloads raise (HTTP 4xx) and are
    not stored; verified ones are idempotent on `notificationUUID`."""
    outer = apple.verify_jws(signed_payload)
    notification_id = str(outer.get("notificationUUID") or "")
    if not notification_id:
        raise ValidationFailed("Missing notification id.")
    ntype, subtype = str(outer.get("notificationType", "")), outer.get("subtype")
    signed_date = datetime.fromtimestamp(int(outer.get("signedDate", 0)) / 1000, tz=UTC)
    data = outer.get("data") or {}
    normalized: NormalizedEvent | None = None
    raw: dict[str, Any] = {
        "notificationType": ntype,
        "subtype": subtype,
        "signedDate": outer.get("signedDate"),
    }
    kind = apple.kind_for_notification(ntype, subtype)
    if kind and data.get("signedTransactionInfo"):
        tx_payload = apple.verify_jws(data["signedTransactionInfo"])
        txn = apple.parse_transaction(tx_payload)
        product = _product_for_apple(txn.product_id)
        raw["transaction"] = _strip(tx_payload)
        normalized = NormalizedEvent(
            kind=kind, provider="apple", transaction_id=txn.original_transaction_id, product_code=product.code,
            event_time=txn.purchase_date if kind == GRANT else signed_date, account_id=txn.account_token,
            period_start=txn.purchase_date if kind == GRANT else None, period_end=txn.expires_date if kind == GRANT else None,
            amount_minor=product.price_minor if kind in (GRANT, "refund") else 0, currency=product.currency,
            auto_renew=(subtype == "AUTO_RENEW_ENABLED") if kind == CANCEL else (True if kind == GRANT else None),
        )  # fmt: skip
    event, _ = services.ingest_event(
        provider="apple", provider_event_id=notification_id, event_type=f"{ntype}:{subtype or ''}"[:60],
        raw=raw, normalized=normalized, signature_valid=True,
    )  # fmt: skip
    if normalized is None and event.process_status == PaymentEvent.Status.PENDING:
        services._finish(event, PaymentEvent.Status.IGNORED, "informational")
    return event


def _strip(payload: dict[str, Any]) -> dict[str, Any]:
    """Keep the ledger useful for audits but free of anything secret-like or personally identifying."""
    keep = {"transactionId", "originalTransactionId", "productId", "purchaseDate", "expiresDate", "revocationDate",
            "environment", "type", "bundleId", "signedDate", "currency", "price", "revocationReason"}  # fmt: skip
    return {k: v for k, v in payload.items() if k in keep}


__all__ = ["handle_apple_notification", "json", "settings", "uuid", "verify_apple_transaction"]


# ============================================================================ Google Play (MC-099)
def _product_for_google(product_id: str) -> Product:
    product = Product.objects.filter(google_product_id=product_id, active=True).first()
    if product is None:
        raise ValidationFailed("Unknown product.")
    return product


def _google_event(
    *, token: str, resource: dict[str, Any], kind: str, now: datetime
) -> tuple[NormalizedEvent, Product]:
    from datetime import timedelta

    from .providers import google

    line = (resource.get("lineItems") or [{}])[0]
    product = _product_for_google(str(line.get("productId", "")))
    expiry = google.parse_time(line.get("expiryTime"))
    account = (resource.get("externalAccountIdentifiers") or {}).get("obfuscatedExternalAccountId")
    return (
        NormalizedEvent(
            kind=kind, provider="google", transaction_id=google.token_key(token), product_code=product.code,
            event_time=now,
            account_id=uuid.UUID(account) if account else None,
            period_start=(expiry - timedelta(days=product.duration_days)) if expiry and kind == GRANT else None,
            period_end=expiry if kind == GRANT else None,
            amount_minor=product.price_minor if kind in (GRANT, "refund") else 0, currency=product.currency,
            auto_renew=bool((line.get("autoRenewingPlan") or {}).get("autoRenewEnabled")) if kind in (GRANT, CANCEL) else None,
        ),
        product,
    )  # fmt: skip


def _set_token(purchase_key: str, token: str) -> None:
    Purchase.objects.filter(
        provider="google", original_transaction_id=purchase_key, provider_token__isnull=True
    ).update(provider_token=token)


def verify_google_purchase(*, account: "Account", product_id: str, purchase_token: str) -> Purchase:
    """`POST /billing/store/verify` (Android): ask Google, bind via obfuscatedExternalAccountId, grant, acknowledge."""
    from .providers import google

    api = google.get_play_api()
    resource = api.get_subscription(purchase_token)
    bound = (resource.get("externalAccountIdentifiers") or {}).get("obfuscatedExternalAccountId")
    if bound != str(account.id):
        raise Forbidden("This purchase belongs to a different account.")
    line = (resource.get("lineItems") or [{}])[0]
    if line.get("productId") != product_id:
        raise ValidationFailed("Product does not match the purchase.")
    if resource.get("subscriptionState") not in google.STATES_WITH_ACCESS:
        raise ValidationFailed("This subscription is not active.")
    now = datetime.now(UTC)
    norm, product = _google_event(token=purchase_token, resource=resource, kind=GRANT, now=now)
    expiry_ms = int((google.parse_time(line.get("expiryTime")) or now).timestamp() * 1000)
    event, _ = services.ingest_event(
        provider="google", provider_event_id=f"verify:{google.token_key(purchase_token)[:24]}:{expiry_ms}",
        event_type="client_verify", raw=_google_raw(resource), normalized=norm, signature_valid=True, account_id=account.id,
    )  # fmt: skip
    services.process_event(event_id=event.id)
    _set_token(norm.transaction_id, purchase_token)
    if resource.get("acknowledgementState") == "ACKNOWLEDGEMENT_STATE_PENDING":
        api.acknowledge(
            product_id=product.google_product_id, purchase_token=purchase_token
        )  # must happen within 3 days
    purchase = Purchase.objects.filter(
        provider="google", original_transaction_id=norm.transaction_id
    ).first()
    if purchase is None:
        raise NotFound()
    return purchase


def handle_google_rtdn(*, message_id: str, payload: dict[str, Any]) -> PaymentEvent | None:
    """`POST /webhooks/google` (after OIDC verification): turn a notification into a ledger event.

    State-based: for subscription notifications we re-read the subscription from Google and derive the event, so
    duplicates and out-of-order delivery converge. Idempotent on the Pub/Sub `messageId`."""
    from .providers import google

    if payload.get("packageName") != settings.GOOGLE_PACKAGE_NAME:
        raise ValidationFailed("Notification is for a different app.")
    now = datetime.now(UTC)
    api = google.get_play_api()
    sub = payload.get("subscriptionNotification")
    void = payload.get("voidedPurchaseNotification")
    if sub:
        token, ntype = str(sub["purchaseToken"]), int(sub["notificationType"])
        kind = {google.CANCELED: CANCEL, google.REVOKED: "revoke"}.get(ntype)
        if ntype in (
            google.PURCHASED,
            google.RENEWED,
            google.RECOVERED,
            google.RESTARTED,
            google.DEFERRED,
        ):
            kind = GRANT
        if (
            kind is None
        ):  # expired / on hold / grace / paused: access follows the dates we already have
            event, _ = services.ingest_event(
                provider="google",
                provider_event_id=message_id,
                event_type=f"rtdn:{ntype}",
                raw={"type": ntype},
                normalized=None,
                signature_valid=True,
            )
            return event
        resource = api.get_subscription(token)
        norm, product = _google_event(token=token, resource=resource, kind=kind, now=now)
        event, created = services.ingest_event(
            provider="google", provider_event_id=message_id, event_type=f"rtdn:{ntype}",
            raw={"type": ntype, **_google_raw(resource)}, normalized=norm, signature_valid=True,
        )  # fmt: skip
        if created:
            services.process_event(event_id=event.id)
            _set_token(norm.transaction_id, token)
            if (
                kind == GRANT
                and resource.get("acknowledgementState") == "ACKNOWLEDGEMENT_STATE_PENDING"
            ):
                api.acknowledge(product_id=product.google_product_id, purchase_token=token)
        return event
    if void:
        token = str(void["purchaseToken"])
        key = google.token_key(token)
        purchase = (
            Purchase.objects.filter(provider="google", original_transaction_id=key)
            .select_related("product")
            .first()
        )
        if purchase is None:
            return services.ingest_event(
                provider="google",
                provider_event_id=message_id,
                event_type="rtdn:voided",
                raw={"orderId": void.get("orderId", "")},
                normalized=None,
                signature_valid=True,
            )[0]
        norm = NormalizedEvent(
            kind="refund", provider="google", transaction_id=key, product_code=purchase.product.code, event_time=now,
            account_id=purchase.account_id, amount_minor=purchase.product.price_minor, currency=purchase.product.currency,
        )  # fmt: skip
        event, created = services.ingest_event(
            provider="google",
            provider_event_id=message_id,
            event_type="rtdn:voided",
            raw={"orderId": void.get("orderId", "")},
            normalized=norm,
            signature_valid=True,
        )
        if created:
            services.process_event(event_id=event.id)
        return event
    return services.ingest_event(
        provider="google",
        provider_event_id=message_id,
        event_type="rtdn:other",
        raw={"keys": sorted(payload)},
        normalized=None,
        signature_valid=True,
    )[0]


def _google_raw(resource: dict[str, Any]) -> dict[str, Any]:
    """Ledger copy without the account binding or order identifiers beyond what audits need."""
    line = (resource.get("lineItems") or [{}])[0]
    return {
        "subscriptionState": resource.get("subscriptionState"),
        "productId": line.get("productId"),
        "expiryTime": line.get("expiryTime"),
        "startTime": resource.get("startTime"),
        "latestOrderId": resource.get("latestOrderId"),
        "acknowledgementState": resource.get("acknowledgementState"),
    }

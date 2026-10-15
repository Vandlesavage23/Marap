"""Web checkout (MC-100): prepaid periods paid by mobile money or card. Amount and product always come from OUR
catalogue; the gateway's word is only accepted after a server-side re-verification."""

import hmac
import uuid
from typing import TYPE_CHECKING, Any

from django.conf import settings
from django.db import transaction
from django.utils import timezone

from mc.common import ratelimit
from mc.common.errors import ProviderError, ValidationFailed

from . import selectors, services
from .events import GRANT, NormalizedEvent
from .models import PaymentEvent, Purchase
from .providers.flutterwave import get_gateway

if TYPE_CHECKING:
    from mc.accounts.models import Account

NETWORKS = {"mtn", "airtel"}


def start_checkout(
    *, account: "Account", product_code: str, method: str, phone: str = "", network: str = ""
) -> tuple[Purchase, dict[str, str]]:
    """Create a pending Purchase (tx_ref = its id) and ask the gateway to start the charge."""
    if not settings.WEB_CHECKOUT_ENABLED:  # PENDING OD-01
        raise ValidationFailed("Web checkout isn't available.")
    product = selectors.get_product(product_code)
    if product is None or not product.web_enabled:
        raise ValidationFailed("Unknown product.")
    if method not in ("mobile_money", "card"):
        raise ValidationFailed("Unknown payment method.")
    if method == "mobile_money":
        if network not in NETWORKS:
            raise ValidationFailed("Choose MTN or Airtel.")
        from mc.accounts import phone as phone_utils

        phone = phone_utils.normalise(phone or account.phone_e164)
    ratelimit.hit(f"checkout:{account.id}", limit=10, window_seconds=3600)
    purchase_id = uuid.uuid4()
    purchase = Purchase.objects.create(
        id=purchase_id, account=account, provider="flutterwave", product=product,
        original_transaction_id=str(purchase_id), amount_minor=product.price_minor, currency=product.currency,
    )  # fmt: skip
    try:
        charge = get_gateway().create_charge(
            tx_ref=str(purchase_id),
            amount=product.price_minor,
            currency=product.currency,
            method=method,
            phone=phone,
            network=network,
        )
    except ProviderError:
        Purchase.objects.filter(
            id=purchase_id
        ).delete()  # nothing was charged; let the member retry cleanly
        raise
    out = {"link": charge.link} if charge.link else {"instruction": charge.pending_instruction}
    return purchase, out


def handle_flutterwave_webhook(*, verif_hash: str, payload: dict[str, Any]) -> PaymentEvent | None:
    """`POST /webhooks/flutterwave`. 1) header must equal our secret; 2) re-fetch the transaction from the gateway;
    3) amount/currency/tx_ref/status must match our purchase; only then record a grant."""
    if not settings.FLUTTERWAVE_WEBHOOK_HASH or not hmac.compare_digest(
        verif_hash or "", settings.FLUTTERWAVE_WEBHOOK_HASH
    ):
        from mc.common.errors import Unauthenticated

        raise Unauthenticated()
    data = payload.get("data") or {}
    tx_id = str(data.get("id", ""))
    if not tx_id:
        raise ValidationFailed("Missing transaction id.")
    return confirm_transaction(transaction_id=tx_id, source="webhook")


def confirm_transaction(*, transaction_id: str, source: str) -> PaymentEvent | None:
    gw = get_gateway()
    verified = gw.verify_transaction(
        transaction_id
    )  # ProviderError → 502 → provider retries the webhook
    return _apply(verified, source=source)


def _apply(verified, *, source: str) -> PaymentEvent | None:  # type: ignore[no-untyped-def]
    now = timezone.now()
    purchase = (
        Purchase.objects.select_related("product")
        .filter(provider="flutterwave", original_transaction_id=verified.tx_ref)
        .first()
    )
    event_id = f"flw:{verified.transaction_id}"
    raw = {
        "source": source,
        "status": verified.status,
        "amount": verified.amount,
        "currency": verified.currency,
        "tx_ref": verified.tx_ref,
    }
    if purchase is None:
        return services.ingest_event(
            provider="flutterwave",
            provider_event_id=event_id,
            event_type="unknown_tx_ref",
            raw=raw,
            normalized=None,
            signature_valid=True,
        )[0]
    if verified.status != "successful":
        return services.ingest_event(
            provider="flutterwave",
            provider_event_id=f"{event_id}:{verified.status}",
            event_type=f"charge.{verified.status}",
            raw=raw,
            normalized=None,
            signature_valid=True,
        )[0]
    if verified.amount < purchase.amount_minor or verified.currency != purchase.currency:
        event, _ = services.ingest_event(
            provider="flutterwave",
            provider_event_id=event_id,
            event_type="amount_mismatch",
            raw=raw,
            normalized=None,
            signature_valid=True,
        )
        if event.process_status == PaymentEvent.Status.PENDING or event.error == "":
            services._finish(event, PaymentEvent.Status.FAILED, "amount_or_currency_mismatch")
        return event
    norm = NormalizedEvent(
        kind=GRANT, provider="flutterwave", transaction_id=purchase.original_transaction_id, product_code=purchase.product.code,
        event_time=now, account_id=purchase.account_id, amount_minor=purchase.amount_minor, currency=purchase.currency, auto_renew=False,
    )  # fmt: skip
    with transaction.atomic():
        event, created = services.ingest_event(
            provider="flutterwave",
            provider_event_id=event_id,
            event_type="charge.completed",
            raw=raw,
            normalized=norm,
            signature_valid=True,
            account_id=purchase.account_id,
        )
    if created:
        services.process_event(event_id=event.id)
    return event


def purchase_status(*, account: "Account", purchase_id: uuid.UUID) -> Purchase | None:
    return (
        Purchase.objects.filter(id=purchase_id, account=account, provider="flutterwave")
        .select_related("product")
        .first()
    )

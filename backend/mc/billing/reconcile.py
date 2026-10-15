"""Reconciliation (MC-101): the safety net for lost webhooks and drifted state.

* `sweep_pending_web` (every 10 min): ask the gateway about web purchases still pending after 10 minutes.
* `reconcile_google` : re-read active Google subscriptions and feed any change through the ledger.
* `nightly_report`   : cross-check purchases ↔ ledger ↔ entitlements; any mismatch alerts payments_ops
  (structured WARNING `alert=payments_reconciliation_mismatch` + a system audit event).
"""

import logging
from datetime import timedelta
from typing import Any

from django.utils import timezone

from mc.audit import services as audit
from mc.common.errors import ProviderError
from mc.entitlements.models import Entitlement

from . import services, store, web
from .events import GRANT, NormalizedEvent
from .models import PaymentEvent, Purchase
from .providers.flutterwave import get_gateway
from .providers.google import get_play_api, parse_time

logger = logging.getLogger(__name__)
PENDING_AFTER = timedelta(minutes=10)
ABANDON_AFTER = timedelta(hours=24)


def sweep_pending_web(*, now=None) -> dict[str, int]:  # type: ignore[no-untyped-def]
    now = now or timezone.now()
    out = {"checked": 0, "granted": 0, "abandoned": 0, "errors": 0}
    gw = get_gateway()
    for p in Purchase.objects.filter(
        provider="flutterwave", status=Purchase.Status.PENDING, created_at__lte=now - PENDING_AFTER
    ):
        out["checked"] += 1
        try:
            tx = gw.verify_by_reference(p.original_transaction_id)
        except ProviderError:
            out["errors"] += 1
            continue
        if tx is not None and tx.status == "successful":
            web._apply(tx, source="reconciliation")
            out["granted"] += 1
        elif p.created_at <= now - ABANDON_AFTER:
            Purchase.objects.filter(id=p.id, status=Purchase.Status.PENDING).update(
                status=Purchase.Status.EXPIRED, updated_at=now
            )
            out["abandoned"] += 1
    return out


def reconcile_google(*, now=None) -> dict[str, int]:  # type: ignore[no-untyped-def]
    now = now or timezone.now()
    out = {"checked": 0, "updated": 0, "mismatches": 0, "errors": 0}
    api = get_play_api()
    qs = Purchase.objects.filter(
        provider="google", provider_token__isnull=False, status=Purchase.Status.ACTIVE
    ).select_related("product")
    for p in qs:
        out["checked"] += 1
        try:
            res = api.get_subscription(p.provider_token or "")
        except ProviderError:
            out["errors"] += 1
            continue
        line = (res.get("lineItems") or [{}])[0]
        expiry = parse_time(line.get("expiryTime"))
        if expiry and p.period_end and expiry > p.period_end:
            norm = NormalizedEvent(kind=GRANT, provider="google", transaction_id=p.original_transaction_id, product_code=p.product.code, event_time=now,
                                   account_id=p.account_id, period_start=expiry - timedelta(days=p.product.duration_days), period_end=expiry,
                                   amount_minor=p.product.price_minor, currency=p.product.currency, auto_renew=True)  # fmt: skip
            ev, created = services.ingest_event(
                provider="google",
                provider_event_id=f"recon:{p.original_transaction_id[:24]}:{int(expiry.timestamp())}",
                event_type="reconciliation",
                raw={"expiryTime": line.get("expiryTime")},
                normalized=norm,
                signature_valid=True,
            )
            if created:
                services.process_event(event_id=ev.id)
                out["updated"] += 1
        elif (
            res.get("subscriptionState")
            in ("SUBSCRIPTION_STATE_EXPIRED", "SUBSCRIPTION_STATE_PENDING")
            and p.period_end
            and p.period_end > now + timedelta(hours=1)
        ):
            out["mismatches"] += (
                1  # Google says it's over; we still show access → a human should look
            )
    return out


def nightly_report(*, now=None) -> dict[str, Any]:  # type: ignore[no-untyped-def]
    now = now or timezone.now()
    since = now - timedelta(hours=48)
    mismatches: list[dict[str, str]] = []

    for p in Purchase.objects.filter(status=Purchase.Status.ACTIVE, updated_at__gte=since):
        if not Entitlement.objects.filter(purchase_id=p.id, revoked_at__isnull=True).exists():
            mismatches.append(
                {"purchase": str(p.id), "problem": "active_purchase_without_entitlement"}
            )
        if services.ledger_balance(p) <= 0:
            mismatches.append({"purchase": str(p.id), "problem": "active_purchase_without_payment"})
    for p in Purchase.objects.filter(
        status__in=[Purchase.Status.REFUNDED, Purchase.Status.REVOKED]
    ):
        if Entitlement.objects.filter(
            purchase_id=p.id, revoked_at__isnull=True, ends_at__gt=now
        ).exists():
            mismatches.append(
                {"purchase": str(p.id), "problem": "refunded_purchase_still_entitled"}
            )
    failed = PaymentEvent.objects.filter(
        process_status=PaymentEvent.Status.FAILED, received_at__gte=since
    )
    for ev in failed:
        mismatches.append({"event": str(ev.id), "problem": f"failed_event:{ev.error}"})
    stuck = Purchase.objects.filter(
        provider="flutterwave",
        status=Purchase.Status.PENDING,
        created_at__lte=now - ABANDON_AFTER,
        created_at__gte=since,
    )
    for p in stuck:
        mismatches.append({"purchase": str(p.id), "problem": "pending_over_24h"})

    report = {
        "generated_at": now.isoformat(),
        "window_hours": 48,
        "purchases_active": Purchase.objects.filter(status=Purchase.Status.ACTIVE).count(),
        "events_received": PaymentEvent.objects.filter(received_at__gte=since).count(),
        "mismatches": mismatches,
    }
    if mismatches:
        logger.warning(
            "payments reconciliation found mismatches",
            extra={"alert": "payments_reconciliation_mismatch", "count": len(mismatches)},
        )
        audit.record(
            actor_type="system",
            action="billing.reconciliation_mismatch",
            reason=f"{len(mismatches)} mismatches",
            metadata={
                "count": str(len(mismatches)),
                "problems": ",".join(sorted({m["problem"] for m in mismatches})),
            },
        )
    return report


__all__ = ["nightly_report", "reconcile_google", "store", "sweep_pending_web"]

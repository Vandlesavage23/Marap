"""Payment ledger + purchase processor (Bible §6.1, §10.7, §11).

`ingest_event` stores what a provider said (idempotent on `(provider, provider_event_id)`).
`process_event` is idempotent and ORDER-INDEPENDENT: a purchase's state is recomputed from the full set of its
events sorted by the provider's clock, so duplicates, replays and out-of-order delivery converge on the same
purchase and entitlement windows (the payments-ops worst case: a refund webhook arriving before the purchase)."""

import logging
import uuid
from datetime import datetime, timedelta
from typing import Any

from django.conf import settings
from django.db import IntegrityError, transaction
from django.utils import timezone

from mc.accounts import selectors as account_selectors
from mc.common import events, metrics
from mc.entitlements import selectors as entitlement_selectors
from mc.entitlements import services as entitlement_services

from . import selectors
from .events import CANCEL, GRANT, KINDS, REFUND, REVOKE, NormalizedEvent, PurchaseUpdated
from .models import PaymentEvent, Product, Purchase

log = logging.getLogger(__name__)


def ingest_event(
    *,
    provider: str,
    provider_event_id: str,
    event_type: str,
    raw: dict[str, Any],
    normalized: NormalizedEvent | None,
    signature_valid: bool,
    account_id: uuid.UUID | None = None,
) -> tuple[PaymentEvent, bool]:
    """Append to the ledger. A replay of the same provider event returns the original row untouched."""
    existing = PaymentEvent.objects.filter(
        provider=provider, provider_event_id=provider_event_id
    ).first()
    if existing is not None:
        return existing, False
    claimed = account_id or (normalized.account_id if normalized else None)
    resolved_account = (
        claimed if claimed and account_selectors.get_account(claimed) else None
    )  # unknown id → NULL
    try:
        with transaction.atomic():
            event = PaymentEvent.objects.create(
                provider=provider,
                provider_event_id=provider_event_id,
                event_type=event_type[:60],
                account_id=resolved_account,
                raw=raw,
                normalized=normalized.to_json() if normalized else {},
                signature_valid=signature_valid,
                received_at=timezone.now(),
                process_status=PaymentEvent.Status.PENDING
                if signature_valid and normalized
                else PaymentEvent.Status.IGNORED,
                error="" if signature_valid else "bad_signature",
            )
    except IntegrityError:
        return PaymentEvent.objects.get(
            provider=provider, provider_event_id=provider_event_id
        ), False
    metrics.count_payment_event(provider, "received")
    if event.process_status == PaymentEvent.Status.PENDING:
        from .tasks import process_event as process_event_task

        transaction.on_commit(lambda: process_event_task.delay(str(event.id)))
    return event, True


def _fold(events_: list[NormalizedEvent]) -> dict[str, Any]:
    """Reduce all of a purchase's events (any order) to its state. Pure function."""
    ordered = sorted(events_, key=lambda e: (e.event_time, e.kind))
    state: dict[str, Any] = {
        "refunded": False,
        "revoked": False,
        "start": None,
        "end": None,
        "auto_renew": None,
        "amount": 0,
        "granted": [],
    }
    for e in ordered:
        if e.kind == GRANT:
            state["granted"].append((e.period_start, e.period_end))
            if e.period_end is not None and (state["end"] is None or e.period_end >= state["end"]):
                state["start"], state["end"] = e.period_start, e.period_end
            state["amount"] = e.amount_minor or state["amount"]
            if e.auto_renew is not None:
                state["auto_renew"] = e.auto_renew
        elif e.kind == CANCEL:
            state["auto_renew"] = False if e.auto_renew is None else e.auto_renew
        elif e.kind == REFUND:
            state["refunded"] = True
        elif e.kind == REVOKE:
            state["revoked"] = True
    return state


def _status(state: dict[str, Any], now: datetime) -> str:
    if state["refunded"]:
        return Purchase.Status.REFUNDED
    if state["revoked"]:
        return Purchase.Status.REVOKED
    if state["end"] is not None:
        return Purchase.Status.ACTIVE if now < state["end"] else Purchase.Status.EXPIRED
    return Purchase.Status.PENDING


def _events_for(provider: str, txn: str) -> list[tuple[PaymentEvent, NormalizedEvent]]:
    rows = PaymentEvent.objects.filter(
        provider=provider, normalized__transaction_id=txn, signature_valid=True
    ).exclude(process_status=PaymentEvent.Status.IGNORED)
    return [(row, NormalizedEvent.from_json(row.normalized)) for row in rows]


def process_event(*, event_id: uuid.UUID) -> PaymentEvent | None:
    """Apply one ledger event (and everything else known about its purchase). Safe to call any number of times."""
    now = timezone.now()
    with transaction.atomic():
        event = PaymentEvent.objects.select_for_update().filter(id=event_id).first()
        if event is None or event.process_status in (
            PaymentEvent.Status.PROCESSED,
            PaymentEvent.Status.IGNORED,
        ):
            return event
        if not event.signature_valid or not event.normalized:
            return _finish(event, PaymentEvent.Status.IGNORED, "unverified")
        norm = NormalizedEvent.from_json(event.normalized)
        if norm.kind not in KINDS:
            return _finish(event, PaymentEvent.Status.IGNORED, "unknown_kind")
        product = Product.objects.filter(code=norm.product_code).first()
        if product is None:
            return _finish(event, PaymentEvent.Status.FAILED, "unknown_product")

        purchase = (
            Purchase.objects.select_for_update()
            .filter(provider=norm.provider, original_transaction_id=norm.transaction_id)
            .first()
        )
        account_id = (
            norm.account_id or (purchase.account_id if purchase else None) or event.account_id
        )
        if purchase is None:
            if account_id is None or account_selectors.get_account(account_id) is None:
                return _finish(
                    event, PaymentEvent.Status.FAILED, "account_unresolved"
                )  # retried by reconciliation
            try:
                with transaction.atomic():
                    purchase = Purchase.objects.create(
                        account_id=account_id, provider=norm.provider, product=product,
                        original_transaction_id=norm.transaction_id, currency=norm.currency,
                    )  # fmt: skip
            except IntegrityError:
                purchase = Purchase.objects.select_for_update().get(
                    provider=norm.provider, original_transaction_id=norm.transaction_id
                )
        elif norm.account_id and purchase.account_id != norm.account_id:
            return _finish(event, PaymentEvent.Status.FAILED, "account_mismatch")

        if (
            purchase.account_id is None
        ):  # the member deleted their account: keep the ledger, grant nothing
            return _finish(event, PaymentEvent.Status.PROCESSED, "account_deleted")

        state = _fold([n for _, n in _events_for(norm.provider, norm.transaction_id)] + [norm])
        # Prepaid web periods carry no dates from the provider: fix them once, at first confirmation, so the
        # window starts when current access ends (overlapping purchases extend) and never shifts on replay.
        if state["end"] is None and state["granted"] and purchase.period_end is None:
            base = max(
                now, entitlement_selectors.membership_ends_at(purchase.account_id, now) or now
            )
            purchase.period_start, purchase.period_end = (
                base,
                base + timedelta(days=product.duration_days),
            )
        elif purchase.period_end is not None and state["end"] is None:
            state["start"], state["end"] = purchase.period_start, purchase.period_end
        else:
            purchase.period_start, purchase.period_end = state["start"], state["end"]
        state["end"], state["start"] = purchase.period_end, purchase.period_start

        purchase.status = _status(state, now)
        purchase.auto_renew = bool(state["auto_renew"])
        purchase.amount_minor = state["amount"] or purchase.amount_minor
        purchase.last_event = event
        purchase.save()

        # Always materialise the paid windows first, then revoke them if the purchase was refunded/revoked: both
        # delivery orders (grant→refund and refund→grant) leave the identical audit trail of revoked windows.
        account = account_selectors.get_account(purchase.account_id)
        if account is not None:
            for start, end in {
                (s or purchase.period_start, e or purchase.period_end) for s, e in state["granted"]
            }:
                if start is not None and end is not None:
                    entitlement_services.grant_from_purchase(
                        account=account, purchase_id=purchase.id, period_start=start, period_end=end
                    )
        if purchase.status in (Purchase.Status.REFUNDED, Purchase.Status.REVOKED):
            entitlement_services.revoke_for_purchase(
                purchase_id=purchase.id, reason=purchase.status
            )
        if event.account_id is None:
            event.account_id = purchase.account_id
        events.publish(
            PurchaseUpdated(
                purchase_id=purchase.id, account_id=purchase.account_id, status=purchase.status
            )
        )
        return _finish(event, PaymentEvent.Status.PROCESSED, "")


def _finish(event: PaymentEvent, status: str, error: str) -> PaymentEvent:
    event.process_status, event.error, event.processed_at = status, error, timezone.now()
    event.save(update_fields=["process_status", "error", "processed_at", "account", "updated_at"])
    metrics.count_payment_event(event.provider, status)
    return event


def retry_failed(*, limit: int = 200) -> int:
    """Re-run events that failed only because something they depend on wasn't known yet."""
    n = 0
    for ev in PaymentEvent.objects.filter(
        process_status=PaymentEvent.Status.FAILED, error="account_unresolved"
    )[:limit]:
        PaymentEvent.objects.filter(id=ev.id).update(process_status=PaymentEvent.Status.PENDING)
        process_event(event_id=ev.id)
        n += 1
    return n


def check_webhook_failures(*, now: datetime | None = None) -> int:
    """Beat job: WARNING `alert=payment_webhook_failures` when MORE than `PAYMENT_WEBHOOK_FAILURE_THRESHOLD`
    (5) payment events received in the last `PAYMENT_WEBHOOK_FAILURE_WINDOW_MINUTES` (10) are in `failed`.
    Returns the failed count in the window."""
    now = now or timezone.now()
    window = settings.PAYMENT_WEBHOOK_FAILURE_WINDOW_MINUTES
    by_provider = selectors.failed_webhook_events(since=now - timedelta(minutes=window))
    total = sum(by_provider.values())
    if total > settings.PAYMENT_WEBHOOK_FAILURE_THRESHOLD:
        metrics.count_alert("payment_webhook_failures")
        log.warning(
            "payment webhook failures",
            extra={
                "alert": "payment_webhook_failures",
                "count": total,
                "window_minutes": window,
                "threshold": settings.PAYMENT_WEBHOOK_FAILURE_THRESHOLD,
                "by_provider": by_provider,
            },
        )
    return total


def expire_purchases(*, now: datetime | None = None) -> int:
    """Beat job: `active` → `expired` once the period has ended (status is otherwise derived on events)."""
    now = now or timezone.now()
    return Purchase.objects.filter(status=Purchase.Status.ACTIVE, period_end__lte=now).update(
        status=Purchase.Status.EXPIRED, updated_at=now
    )


def ledger_balance(purchase: Purchase) -> int:
    """Money in minus money out for this purchase from verified events (0 after a full refund)."""
    total = 0
    for _, n in _events_for(purchase.provider, purchase.original_transaction_id):
        if n.kind == GRANT:
            total += n.amount_minor
        elif n.kind == REFUND:
            total -= n.amount_minor
    return total

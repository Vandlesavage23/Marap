"""Payments-ops operations (MC-102). Services take a staff id + role; the admin portal (MC-113) supplies real
StaffUsers and enforces the role matrix, but the role is re-checked here so no caller can skip it."""

import uuid

from django.db import transaction
from django.utils import timezone

from mc.audit import services as audit
from mc.common.errors import Conflict, Forbidden, NotFound, ProviderError, ValidationFailed

from . import services
from .events import REFUND, NormalizedEvent
from .models import PaymentEvent, Purchase
from .providers.flutterwave import get_gateway

REFUND_ROLES = {"payments_ops", "privacy_officer"}
READ_ROLES = {"payments_ops", "privacy_officer", "support"}


def _check(role: str, allowed: set[str]) -> None:
    if role not in allowed:
        raise Forbidden("Your role can't do this.")


def purchases_for_account(*, account_id: uuid.UUID, actor_id: uuid.UUID, role: str):  # type: ignore[no-untyped-def]
    """Read a member's purchases (support sees status only; payments_ops full). The read is audited."""
    _check(role, READ_ROLES)
    audit.record(
        actor_type="staff",
        actor_id=actor_id,
        role=role,
        action="admin.view",
        target_type="account",
        target_id=account_id,
        reason="payments lookup",
    )
    qs = Purchase.objects.filter(account_id=account_id).select_related("product").order_by("-id")
    return qs


def ledger_for_purchase(*, purchase_id: uuid.UUID, actor_id: uuid.UUID, role: str):  # type: ignore[no-untyped-def]
    _check(role, {"payments_ops", "privacy_officer"})
    p = Purchase.objects.filter(id=purchase_id).first()
    if p is None:
        raise NotFound()
    audit.record(
        actor_type="staff",
        actor_id=actor_id,
        role=role,
        action="admin.view",
        target_type="purchase",
        target_id=p.id,
        reason="ledger lookup",
    )
    return PaymentEvent.objects.filter(
        provider=p.provider, normalized__transaction_id=p.original_transaction_id
    ).order_by("received_at")


def refund_web_purchase(
    *, purchase_id: uuid.UUID, actor_id: uuid.UUID, role: str, reason: str
) -> Purchase:
    """Refund a Flutterwave purchase in full: provider refund API → ledger refund event → access revoked.
    Entitlement is revoked entirely (proportional shortening is a PENDING counsel decision)."""
    try:
        return _refund(purchase_id=purchase_id, actor_id=actor_id, role=role, reason=reason)
    except ProviderError:  # audited outside the rolled-back transaction
        audit.record(
            actor_type="staff", actor_id=actor_id, role=role, action="billing.refund_failed",
            target_type="purchase", target_id=purchase_id, reason=reason,
        )  # fmt: skip
        raise


def _refund(*, purchase_id: uuid.UUID, actor_id: uuid.UUID, role: str, reason: str) -> Purchase:
    _check(role, REFUND_ROLES)
    if not reason.strip():
        raise ValidationFailed("A reason is required.")
    with transaction.atomic():
        p = (
            Purchase.objects.select_for_update()
            .select_related("product")
            .filter(id=purchase_id)
            .first()
        )
        if p is None:
            raise NotFound()
        if p.provider != "flutterwave":
            raise ValidationFailed(
                "Store purchases are refunded in the App Store / Google Play, not here."
            )
        if p.status in (Purchase.Status.REFUNDED, Purchase.Status.REVOKED):
            raise Conflict("This purchase was already refunded.")
        charge = (
            PaymentEvent.objects.filter(
                provider="flutterwave",
                normalized__transaction_id=p.original_transaction_id,
                normalized__kind="grant",
                process_status="processed",
            )
            .order_by("received_at")
            .first()
        )
        if charge is None:
            raise ValidationFailed("There is no confirmed payment to refund.")
        gateway_tx_id = charge.provider_event_id.removeprefix("flw:")
        refund_ref = get_gateway().refund(transaction_id=gateway_tx_id, amount=p.amount_minor)
        norm = NormalizedEvent(kind=REFUND, provider="flutterwave", transaction_id=p.original_transaction_id, product_code=p.product.code,
                               event_time=timezone.now(), account_id=p.account_id, amount_minor=p.amount_minor, currency=p.currency)  # fmt: skip
        event, _ = services.ingest_event(
            provider="flutterwave",
            provider_event_id=f"refund:{refund_ref}",
            event_type="admin_refund",
            raw={"actor": str(actor_id)},
            normalized=norm,
            signature_valid=True,
            account_id=p.account_id,
        )
        services.process_event(event_id=event.id)
        audit.record(
            actor_type="staff",
            actor_id=actor_id,
            role=role,
            action="billing.refund",
            target_type="purchase",
            target_id=p.id,
            reason=reason,
            metadata={"amount_minor": str(p.amount_minor), "currency": p.currency},
        )
    p.refresh_from_db()
    return p

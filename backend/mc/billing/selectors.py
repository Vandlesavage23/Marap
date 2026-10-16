import uuid
from datetime import datetime

from .models import PaymentEvent, Product, Purchase


def active_products(*, platform: str) -> list[Product]:
    qs = Product.objects.filter(active=True).order_by("duration_days")
    if platform == "ios":
        return list(qs.exclude(apple_product_id=""))
    if platform == "android":
        return list(qs.exclude(google_product_id=""))
    if platform == "web":
        return list(qs.filter(web_enabled=True))
    return []


def purchase_history(account_id: uuid.UUID):  # type: ignore[no-untyped-def]
    return Purchase.objects.filter(account_id=account_id).select_related("product").order_by("-id")


def get_product(code: str) -> Product | None:
    return Product.objects.filter(code=code, active=True).first()


def export_for_account(account) -> list[dict[str, object]]:  # type: ignore[no-untyped-def]
    return [
        {
            "provider": p.provider,
            "product": p.product.code,
            "status": p.status,
            "amount_minor": p.amount_minor,
            "currency": p.currency,
            "period_start": p.period_start.isoformat() if p.period_start else None,
            "period_end": p.period_end.isoformat() if p.period_end else None,
        }
        for p in purchase_history(account.id)
    ]


def failed_webhook_events(*, since: datetime) -> dict[str, int]:
    """Payment events received since `since` whose processing failed, counted per provider (ledger rows only;
    no payloads, accounts or error text)."""
    rows = (
        PaymentEvent.objects.filter(
            process_status=PaymentEvent.Status.FAILED, received_at__gte=since
        )
        .values_list("provider")
        .order_by()
    )
    counts: dict[str, int] = {}
    for (provider,) in rows:
        counts[provider] = counts.get(provider, 0) + 1
    return counts

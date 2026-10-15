import uuid
from datetime import UTC, datetime, timedelta

from mc.billing import services
from mc.billing.events import GRANT, NormalizedEvent

T0 = datetime(2026, 11, 1, 9, 0, tzinfo=UTC)


def ev(
    kind,
    txn="txn-1",
    *,
    acct,
    at=0,
    start=None,
    end=None,
    product="membership_1m",
    provider="apple",
    amount=20000,
    auto=None,
):
    return NormalizedEvent(
        kind=kind, provider=provider, transaction_id=txn, product_code=product,
        event_time=T0 + timedelta(hours=at), account_id=acct.id,
        period_start=(T0 + timedelta(days=start)) if start is not None else None,
        period_end=(T0 + timedelta(days=end)) if end is not None else None,
        amount_minor=amount if kind in (GRANT, "refund") else 0, auto_renew=auto,
    )  # fmt: skip


_n = iter(range(10**6))


def feed(e: NormalizedEvent, *, provider_event_id=None, valid=True):
    event, created = services.ingest_event(
        provider=e.provider, provider_event_id=provider_event_id or f"evt-{next(_n)}", event_type=e.kind,
        raw={"note": "test"}, normalized=e, signature_valid=valid,
    )  # fmt: skip
    services.process_event(event_id=event.id)
    event.refresh_from_db()
    return event


def new_account(phone=None):
    from mc.accounts.models import Account

    return Account.objects.create(phone_e164=phone or f"+2567733{next(_n):05d}", status="active")


__all__ = ["T0", "ev", "feed", "new_account", "uuid"]

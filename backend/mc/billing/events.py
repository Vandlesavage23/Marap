"""Provider-agnostic payment facts. Provider adapters (Apple/Google/Flutterwave) turn *verified* raw payloads
into `NormalizedEvent`s; the processor only ever sees these."""

import uuid
from dataclasses import asdict, dataclass
from datetime import datetime

from mc.common.events import DomainEvent

GRANT, CANCEL, EXPIRE, REFUND, REVOKE = "grant", "cancel", "expire", "refund", "revoke"
KINDS = {GRANT, CANCEL, EXPIRE, REFUND, REVOKE}


@dataclass(frozen=True)
class NormalizedEvent:
    kind: str  # grant (incl. renewals) | cancel (auto-renew off) | expire | refund | revoke
    provider: str
    transaction_id: str  # purchase key within the provider (original transaction / token / tx_ref)
    product_code: str
    event_time: datetime  # provider's clock; ordering key
    account_id: uuid.UUID | None = None
    period_start: datetime | None = None
    period_end: datetime | None = None
    amount_minor: int = (
        0  # signed meaning is implied by `kind`: grant = money in, refund = money out
    )
    currency: str = "UGX"
    auto_renew: bool | None = None

    def to_json(self) -> dict[str, object]:
        d = asdict(self)
        return {
            k: (
                v.isoformat()
                if isinstance(v, datetime)
                else str(v)
                if isinstance(v, uuid.UUID)
                else v
            )
            for k, v in d.items()
        }

    @classmethod
    def from_json(cls, d: dict[str, object]) -> "NormalizedEvent":
        def dt(v):  # type: ignore[no-untyped-def]
            return datetime.fromisoformat(v) if v else None

        return cls(
            kind=str(d["kind"]),
            provider=str(d["provider"]),
            transaction_id=str(d["transaction_id"]),
            product_code=str(d["product_code"]),
            event_time=dt(d["event_time"]),
            account_id=uuid.UUID(str(d["account_id"])) if d.get("account_id") else None,
            period_start=dt(d.get("period_start")),
            period_end=dt(d.get("period_end")),
            amount_minor=int(d.get("amount_minor") or 0),  # type: ignore[call-overload]
            currency=str(d.get("currency") or "UGX"),
            auto_renew=d.get("auto_renew"),  # type: ignore[arg-type]
        )


@dataclass(frozen=True)
class PurchaseUpdated(DomainEvent):
    purchase_id: uuid.UUID
    account_id: uuid.UUID
    status: str

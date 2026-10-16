"""Single source of truth for what an account may do (Bible §10.7)."""

import uuid
from dataclasses import dataclass
from datetime import datetime

from django.conf import settings
from django.db.models import QuerySet
from django.utils import timezone

from mc.verification import selectors as verification_selectors

from .models import Entitlement, Trial

CAPABILITIES = (
    "browse",
    "send_interest",
    "receive_interest",
    "accept_interest",
    "send_message",
    "read_conversations",
)


@dataclass(frozen=True)
class EntitlementState:
    state: str  # none | trial | member | expired
    verified: bool
    trial_used: bool
    trial_ends_at: datetime | None
    membership_ends_at: datetime | None
    membership_source: str | None
    capabilities: dict[str, bool]


def _active(account_id: uuid.UUID, now: datetime) -> QuerySet[Entitlement]:
    return Entitlement.objects.filter(
        account_id=account_id, starts_at__lte=now, ends_at__gt=now, revoked_at__isnull=True
    )


def _capabilities(state: str, verified: bool) -> dict[str, bool]:
    if not verified:
        return dict.fromkeys(CAPABILITIES, False)
    full = state in ("trial", "member")
    accept = full or settings.NONMEMBER_CAN_ACCEPT_INTEREST
    return {
        "browse": full,
        "send_interest": full,
        "receive_interest": True,
        "accept_interest": accept,
        "send_message": full,
        "read_conversations": True,
    }


def state_for(
    account_id: uuid.UUID, *, verified: bool, now: datetime | None = None
) -> EntitlementState:
    now = now or timezone.now()
    active = list(_active(account_id, now).order_by("-ends_at"))
    member = next((e for e in active if e.source != Entitlement.Source.TRIAL), None)
    trial_ent = next((e for e in active if e.source == Entitlement.Source.TRIAL), None)
    trial = Trial.objects.filter(account_id=account_id).first()
    if member:
        state = "member"
    elif trial_ent:
        state = "trial"
    elif Entitlement.objects.filter(account_id=account_id).exists():
        state = "expired"
    else:
        state = "none"
    return EntitlementState(
        state=state,
        verified=verified,
        trial_used=trial is not None,
        trial_ends_at=trial.ends_at if trial else None,
        membership_ends_at=membership_ends_at(account_id, now) if member else None,
        membership_source=member.source if member else None,
        capabilities=_capabilities(state, verified),
    )


def capabilities_for(account, now: datetime | None = None) -> dict[str, bool]:  # type: ignore[no-untyped-def]
    """`{capability: bool}` for an account at `now` (server clock). Accepts a Account instance."""
    verified = verification_selectors.is_verified_adult(account)
    return state_for(account.id, verified=verified, now=now).capabilities


def entitlement_summary(account, now: datetime | None = None) -> EntitlementState:  # type: ignore[no-untyped-def]
    verified = verification_selectors.is_verified_adult(account)
    return state_for(account.id, verified=verified, now=now)


def has_capability(account, capability: str, now: datetime | None = None) -> bool:  # type: ignore[no-untyped-def]
    return capabilities_for(account, now).get(capability, False)


def membership_ends_at(account_id: uuid.UUID, now: datetime | None = None) -> datetime | None:
    """Latest end of any non-revoked, non-trial window that hasn't ended, including windows that start later
    (queued back-to-back purchases). Billing uses it to start the next prepaid period where access ends."""
    now = now or timezone.now()
    ent = (
        Entitlement.objects.filter(account_id=account_id, revoked_at__isnull=True, ends_at__gt=now)
        .exclude(source=Entitlement.Source.TRIAL)
        .order_by("-ends_at")
        .first()
    )
    return ent.ends_at if ent else None


def has_unrevoked_window(
    purchase_id: uuid.UUID, *, still_running_at: datetime | None = None
) -> bool:
    """Is there a non-revoked window for this purchase (optionally one that hasn't ended at `still_running_at`)?"""
    qs = Entitlement.objects.filter(purchase_id=purchase_id, revoked_at__isnull=True)
    if still_running_at is not None:
        qs = qs.filter(ends_at__gt=still_running_at)
    return qs.exists()


def export_for_account(account) -> dict[str, object]:  # type: ignore[no-untyped-def]
    trial = Trial.objects.filter(account=account).first()
    return {
        "trial": {"started_at": trial.started_at.isoformat(), "ends_at": trial.ends_at.isoformat()}
        if trial
        else None,
        "entitlements": [
            {
                "source": e.source,
                "starts_at": e.starts_at.isoformat(),
                "ends_at": e.ends_at.isoformat(),
                "revoked": e.revoked_at is not None,
            }
            for e in Entitlement.objects.filter(account=account).order_by("starts_at")
        ],
    }


def funnel_member_count(*, start: datetime, end: datetime) -> int | None:
    """Dashboard funnel, last stage: accounts registered in `[start, end)` that have held a paid, un-refunded
    membership (a purchase-backed entitlement, trial and staff grants excluded)."""
    from mc.common.aggregates import suppress

    n = (
        Entitlement.objects.filter(
            source=Entitlement.Source.PURCHASE,
            revoked_at__isnull=True,
            account__created_at__gte=start,
            account__created_at__lt=end,
        )
        .values("account_id")
        .distinct()
        .count()
    )
    return suppress(n)

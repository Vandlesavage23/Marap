"""Single source of truth for what an account may do (Bible §10.7)."""

import uuid
from dataclasses import dataclass, replace
from datetime import datetime

from django.conf import settings
from django.db.models import QuerySet
from django.utils import timezone

from mc.verification import selectors as verification_selectors

from .models import Entitlement, Trial

CAPABILITIES = (
    "browse",  # everyone signed in; unverified viewers get limited payloads (see `view_full_profile`)
    "view_full_profile",
    "send_interest",  # verified; free accounts are held to a rolling weekly quota by interests.services
    "receive_interest",
    "accept_interest",
    "send_message",  # inside a match
    "read_conversations",
    "priority_placement",  # membership/trial reach perks (flags only: payment never feeds ranking, Bible §10.6)
    "extra_filters",
    "higher_interest_cap",
    "account_controls",
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
    trial_started_at: datetime | None = None
    trial_available: bool = False  # verified, and neither this account nor this person has used the trial


def _active(account_id: uuid.UUID, now: datetime) -> QuerySet[Entitlement]:
    return Entitlement.objects.filter(
        account_id=account_id, starts_at__lte=now, ends_at__gt=now, revoked_at__isnull=True
    )


def _capabilities(state: str, verified: bool) -> dict[str, bool]:
    """Capabilities v2 (docs/design/user-flow-v2.md §3). Signed-in members can always browse and use account
    controls; an unverified member sees limited payloads and can't affect anyone else; a verified one can send
    (quota for free/expired), receive, accept and chat; trial/member add reach perks."""
    full = verified and state in ("trial", "member")
    return {
        "browse": True,
        "view_full_profile": verified,
        "send_interest": verified,
        "receive_interest": verified,
        "accept_interest": verified and (full or settings.NONMEMBER_CAN_ACCEPT_INTEREST),
        "send_message": verified and (full or settings.FREE_CHAT_IN_MATCH),
        "read_conversations": verified,
        "priority_placement": full,
        "extra_filters": full,
        "higher_interest_cap": full,
        "account_controls": True,
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
        trial_started_at=trial.started_at if trial else None,
    )


def capabilities_for(account, now: datetime | None = None) -> dict[str, bool]:  # type: ignore[no-untyped-def]
    """`{capability: bool}` for an account at `now` (server clock). Accepts a Account instance."""
    verified = verification_selectors.is_verified_adult(account)
    return state_for(account.id, verified=verified, now=now).capabilities


def entitlement_summary(account, now: datetime | None = None) -> EntitlementState:  # type: ignore[no-untyped-def]
    verified = verification_selectors.is_verified_adult(account)
    st = state_for(account.id, verified=verified, now=now)
    return replace(st, trial_available=verified and _trial_unused(account, st))


def _trial_unused(account, st: EntitlementState) -> bool:  # type: ignore[no-untyped-def]
    """One trial per account AND per person (identity hash survives account deletion)."""
    if st.trial_used:
        return False
    identity = verification_selectors.identity_hmac(account)
    return identity is not None and not Trial.objects.filter(identity_hmac=identity).exists()


def can_start_trial(account, now: datetime | None = None) -> bool:  # type: ignore[no-untyped-def]
    return entitlement_summary(account, now).trial_available


def is_unlimited_interest_sender(state: str) -> bool:
    """Trial and membership are bounded by the daily cap only; free and expired accounts by the weekly quota."""
    return state in ("trial", "member")


def browse_card_limit(st: EntitlementState) -> int | None:
    """Cards per Kampala day, or None for no daily cap (trial/member; exposure caps still apply)."""
    if st.state in ("trial", "member") and st.verified:
        return None
    return (
        settings.BROWSE_CARDS_PER_DAY_FREE if st.verified else settings.BROWSE_CARDS_PER_DAY_UNVERIFIED
    )


def profile_open_limit(st: EntitlementState) -> int | None:
    """Full or limited profile opens per Kampala day; only unverified viewers are capped."""
    return None if st.verified else settings.PROFILE_OPENS_PER_DAY_UNVERIFIED


def browse_allowed(account) -> bool:  # type: ignore[no-untyped-def]
    """`browse` in capabilities v2 holds for every signed-in member whatever their state (verification only
    limits WHAT they see). Hot paths that only need this one answer (batched card building) call it instead of
    resolving the whole capability set; `capabilities_for` stays the single definition (`_capabilities`)."""
    return _capabilities("none", False)["browse"]


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

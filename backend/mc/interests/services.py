"""Interest lifecycle (Bible §10.4). Every transition is one transaction; races converge on DB constraints."""

import uuid
from datetime import datetime, timedelta
from typing import TYPE_CHECKING, Any

from django.conf import settings
from django.db import IntegrityError, connection, transaction
from django.utils import timezone

from mc.common import events
from mc.common.errors import (
    Conflict,
    DescriptionRejected,
    Duplicate,
    EntitlementRequired,
    LimitReached,
    NotEligible,
    NotFound,
    ProfileIncomplete,
)
from mc.common.timeutil import start_of_kampala_day
from mc.discovery import services as discovery_services
from mc.entitlements import selectors as entitlement_selectors
from mc.matches import selectors as match_selectors
from mc.matches import services as match_services
from mc.profiles import selectors as profile_selectors
from mc.safety import selectors as safety_selectors

from .events import InterestSent
from .models import Interest, InterestSnapshot

if TYPE_CHECKING:
    from mc.accounts.models import Account


def _pair_lock(a: uuid.UUID, b: uuid.UUID) -> None:
    """Serialise all interest activity for one unordered pair (prevents A→B and B→A crossing in flight)."""
    lo, hi = (a, b) if a < b else (b, a)
    with connection.cursor() as cur:
        cur.execute(
            "SELECT pg_advisory_xact_lock(hashtextextended(%s, 0))", [f"interest:{lo}:{hi}"]
        )


def _require(account: "Account", capability: str, now: datetime) -> None:
    if not entitlement_selectors.has_capability(account, capability, now):
        raise EntitlementRequired(
            "This needs an active trial or membership.", capability=capability
        )


def _daily_limit(account: "Account", now: datetime) -> int:
    state = entitlement_selectors.entitlement_summary(account, now).state
    return (
        settings.INTEREST_DAILY_LIMIT_MEMBER
        if state == "member"
        else settings.INTEREST_DAILY_LIMIT_TRIAL
    )


def send_interest(
    *, sender: "Account", recipient_profile_id: uuid.UUID, idempotency_key: str
) -> dict[str, Any]:
    """Send an interest, or — if the recipient already has a pending interest to the sender — accept it.

    Returns `{"created": bool, "interest": Interest, "match_id": UUID|None, "remaining_today": int|None}`.
    """
    now = timezone.now()
    replay = Interest.objects.filter(sender=sender, idempotency_key=idempotency_key).first()
    if replay is not None:
        return _result(replay, created=False, sender=sender, now=now)

    _require(sender, "send_interest", now)
    recipient_account_id = profile_selectors.account_id_for_profile(recipient_profile_id)
    if recipient_account_id is None or recipient_account_id == sender.id:
        raise NotEligible("You can't send an interest to this profile.")

    with transaction.atomic():
        _pair_lock(sender.id, recipient_account_id)
        replay = Interest.objects.filter(sender=sender, idempotency_key=idempotency_key).first()
        if replay is not None:  # lost a race with our own retry
            return _result(replay, created=False, sender=sender, now=now)

        from mc.accounts.selectors import get_account  # read via selector, never the model directly

        recipient = get_account(recipient_account_id)
        sender_profile = profile_selectors.get_profile_for_account(sender.id)
        if sender_profile is None or sender_profile.status != "live":
            raise ProfileIncomplete("Finish your profile before sending interests.")
        description = sender_profile.current_description
        if description is None:
            raise DescriptionRejected("Add an approved description before sending interests.")
        # Blocks are never revealed: they surface as `not_eligible`, same as failed filters.
        if (
            recipient is None
            or recipient.status != "active"
            or safety_selectors.is_blocked_either_way(sender.id, recipient.id)
            or not discovery_services.are_mutually_eligible(sender, recipient)
        ):
            raise NotEligible("You can't send an interest to this profile.")

        # recipient already interested in the sender → this call is an accept
        reverse = (
            Interest.objects.select_for_update()
            .filter(sender=recipient, recipient=sender, status=Interest.Status.PENDING)
            .first()
        )
        if reverse is not None and reverse.expires_at > now:
            match, _ = match_services.create_match(account_x=sender.id, account_y=recipient.id)
            reverse.status, reverse.responded_at = Interest.Status.ACCEPTED, now
            reverse.save(update_fields=["status", "responded_at", "updated_at"])
            discovery_services.record_interest_action(
                viewer_id=sender.id, candidate_id=recipient.id
            )
            return {
                "created": False,
                "interest": reverse,
                "match_id": match.id,
                "remaining_today": None,
            }

        existing = Interest.objects.filter(
            sender=sender, recipient=recipient, status=Interest.Status.PENDING
        ).first()
        if existing is not None:
            raise Duplicate(
                "You've already sent an interest to this person.", interest_id=str(existing.id)
            )

        sent_today = Interest.objects.filter(
            sender=sender, created_at__gte=start_of_kampala_day(now)
        ).count()
        limit = _daily_limit(sender, now)
        if sent_today >= limit:
            raise LimitReached(
                "You've reached today's limit for interests. Try again tomorrow.",
                retry_after=3600,
                limit=limit,
            )

        cooldown_since = now - timedelta(days=settings.INTEREST_RESEND_COOLDOWN_DAYS)
        if Interest.objects.filter(
            sender=sender,
            recipient=recipient,
            status__in=[Interest.Status.PASSED, Interest.Status.EXPIRED],
            created_at__gte=cooldown_since,
        ).exists():
            raise NotEligible(
                "You can't send an interest to this profile right now."
            )  # never reveals "passed"

        snapshot = InterestSnapshot.objects.create(
            description=description, text=description.text, display_name=sender_profile.display_name
        )
        try:
            with transaction.atomic():
                interest = Interest.objects.create(
                    sender=sender,
                    recipient=recipient,
                    snapshot=snapshot,
                    idempotency_key=idempotency_key,
                    expires_at=now + timedelta(days=settings.INTEREST_EXPIRY_DAYS),
                )
        except (
            IntegrityError
        ) as exc:  # parallel duplicate that slipped past the lock (belt and braces)
            snapshot.delete()
            found = Interest.objects.filter(sender=sender, idempotency_key=idempotency_key).first()
            if found:
                return _result(found, created=False, sender=sender, now=now)
            pend = Interest.objects.filter(
                sender=sender, recipient=recipient, status=Interest.Status.PENDING
            ).first()
            raise Duplicate(
                "You've already sent an interest to this person.",
                interest_id=str(pend.id) if pend else None,
            ) from exc
        discovery_services.record_interest_action(viewer_id=sender.id, candidate_id=recipient.id)
        events.publish(
            InterestSent(interest_id=interest.id, sender_id=sender.id, recipient_id=recipient.id)
        )
    return {
        "created": True,
        "interest": interest,
        "match_id": None,
        "remaining_today": max(limit - sent_today - 1, 0),
    }


def _result(
    interest: Interest, *, created: bool, sender: "Account", now: datetime
) -> dict[str, Any]:
    match_id = None
    if interest.status == Interest.Status.ACCEPTED:
        m = match_selectors.active_match_between(interest.sender_id, interest.recipient_id)
        match_id = m.id if m else None
    sent_today = Interest.objects.filter(
        sender=sender, created_at__gte=start_of_kampala_day(now)
    ).count()
    return {
        "created": created,
        "interest": interest,
        "match_id": match_id,
        "remaining_today": max(_daily_limit(sender, now) - sent_today, 0),
    }


# ----------------------------------------------------------------------------- MC-066
def accept_interest(*, recipient: "Account", interest_id: uuid.UUID) -> tuple[Interest, uuid.UUID]:
    """Recipient accepts → exactly one active match. Idempotent for an already-accepted interest."""
    now = timezone.now()
    _require(recipient, "accept_interest", now)
    expired = False
    with transaction.atomic():
        interest = (
            Interest.objects.select_for_update().filter(id=interest_id, recipient=recipient).first()
        )
        if interest is None:
            raise NotFound()
        _pair_lock(interest.sender_id, interest.recipient_id)
        interest.refresh_from_db()
        if interest.status == Interest.Status.ACCEPTED:
            match, _ = match_services.create_match(
                account_x=interest.sender_id, account_y=interest.recipient_id
            )
            return interest, match.id
        if interest.status != Interest.Status.PENDING:
            raise Conflict("This interest is no longer available.")
        if interest.expires_at <= now:
            interest.status = Interest.Status.EXPIRED
            interest.save(update_fields=["status", "updated_at"])
            expired = True
        else:
            if safety_selectors.is_blocked_either_way(interest.sender_id, interest.recipient_id):
                raise NotFound()
            match, _ = match_services.create_match(
                account_x=interest.sender_id, account_y=interest.recipient_id
            )
            interest.status, interest.responded_at = Interest.Status.ACCEPTED, now
            interest.save(update_fields=["status", "responded_at", "updated_at"])
    if expired:  # raised after the transaction so the `expired` status is persisted
        raise Conflict("This interest has expired.")
    return interest, match.id


def pass_interest(*, recipient: "Account", interest_id: uuid.UUID) -> Interest:
    """Recipient declines. The sender is never told: their list keeps showing `pending` until it expires."""
    with transaction.atomic():
        interest = (
            Interest.objects.select_for_update().filter(id=interest_id, recipient=recipient).first()
        )
        if interest is None:
            raise NotFound()
        if interest.status == Interest.Status.PASSED:
            return interest
        if interest.status != Interest.Status.PENDING:
            raise Conflict("This interest is no longer available.")
        interest.status, interest.responded_at = Interest.Status.PASSED, timezone.now()
        interest.save(update_fields=["status", "responded_at", "updated_at"])
    return interest


def expire_interests(*, now: datetime | None = None) -> int:
    """Beat job (idempotent): pending interests past `expires_at` → expired."""
    now = now or timezone.now()
    total = 0
    while True:
        ids = list(
            Interest.objects.filter(status=Interest.Status.PENDING, expires_at__lte=now)
            .order_by("expires_at")
            .values_list("id", flat=True)[: settings.INTEREST_EXPIRY_BATCH]
        )
        if not ids:
            return total
        total += Interest.objects.filter(id__in=ids, status=Interest.Status.PENDING).update(
            status=Interest.Status.EXPIRED, updated_at=now
        )


def cancel_between(*, a: uuid.UUID, b: uuid.UUID) -> int:
    """Block/deletion: cancel pending interests both ways and delete their snapshots (safety calls this
    inside the block transaction)."""
    qs = Interest.objects.filter(status=Interest.Status.PENDING).filter(
        sender_id__in=[a, b], recipient_id__in=[a, b]
    )
    snapshot_ids = list(qs.values_list("snapshot_id", flat=True))
    n = qs.update(status=Interest.Status.CANCELLED, updated_at=timezone.now())
    InterestSnapshot.objects.filter(id__in=[s for s in snapshot_ids if s]).delete()
    return n

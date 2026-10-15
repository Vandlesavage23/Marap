import uuid
from datetime import datetime, timedelta
from functools import partial
from typing import TYPE_CHECKING

from django.conf import settings
from django.db import IntegrityError, transaction
from django.utils import timezone

from mc.audit import services as audit
from mc.common import events
from mc.common.errors import NotVerified, TrialAlreadyUsed, ValidationFailed
from mc.verification import selectors as verification_selectors

from .events import EntitlementChanged
from .models import Entitlement, Trial

if TYPE_CHECKING:
    from mc.accounts.models import Account

REMINDER_LEAD = timedelta(hours=3)


def start_trial(*, account: "Account") -> Trial:
    """Explicit trial start (button). Verified accounts only; one per identity_hmac; ends_at is
    started_at + TRIAL_DURATION_HOURS on the server clock. No payment details, no auto-conversion."""
    identity = verification_selectors.identity_hmac(account)
    if identity is None:
        raise NotVerified("Verify your identity before starting your free trial.")
    now = timezone.now()
    try:
        with transaction.atomic():
            existing = Trial.objects.filter(account=account).first()
            if existing:
                return existing  # retry of the same user action → same trial (idempotent)
            if Trial.objects.filter(identity_hmac=identity).exists():
                raise TrialAlreadyUsed("The free trial has already been used.")
            trial = Trial.objects.create(
                account=account,
                identity_hmac=identity,
                started_at=now,
                ends_at=now + timedelta(hours=settings.TRIAL_DURATION_HOURS),
            )
            Entitlement.objects.create(
                account=account,
                source=Entitlement.Source.TRIAL,
                starts_at=trial.started_at,
                ends_at=trial.ends_at,
                reason="free trial",
            )
            events.publish(EntitlementChanged(account_id=account.id, reason="trial_started"))
            _schedule_reminders(account.id, trial.started_at, trial.ends_at)
    except IntegrityError as exc:  # concurrent start for the same identity
        raise TrialAlreadyUsed("The free trial has already been used.") from exc
    return trial


def _schedule_reminders(account_id: uuid.UUID, started_at: datetime, ends_at: datetime) -> None:
    from .tasks import send_trial_reminder

    for kind, when in (("ending_soon", ends_at - REMINDER_LEAD), ("ended", ends_at)):
        delay = max(int((when - started_at).total_seconds()), 0)
        transaction.on_commit(
            partial(send_trial_reminder.apply_async, args=[str(account_id), kind], countdown=delay)
        )


def grant_from_purchase(
    *, account: "Account", purchase_id: uuid.UUID, period_start: datetime, period_end: datetime
) -> Entitlement:
    """Create the membership window for a purchase (billing decides the window). Idempotent per purchase
    window: the same (purchase, period_end) never creates two rows."""
    if period_end <= period_start:
        raise ValidationFailed("Invalid membership window.")
    with transaction.atomic():
        ent, created = Entitlement.objects.get_or_create(
            account=account,
            source=Entitlement.Source.PURCHASE,
            purchase_id=purchase_id,
            ends_at=period_end,
            defaults={"starts_at": period_start, "reason": "purchase"},
        )
        if created:
            events.publish(EntitlementChanged(account_id=account.id, reason="purchase"))
    return ent


def grant(
    *, account: "Account", ends_at: datetime, reason: str, actor_id: uuid.UUID, actor_role: str
) -> Entitlement:
    """Manual grant (support/payments_ops). Always audited (CLAUDE.md rule 7/8)."""
    if not reason.strip():
        raise ValidationFailed("A reason is required.")
    now = timezone.now()
    with transaction.atomic():
        ent = Entitlement.objects.create(
            account=account,
            source=Entitlement.Source.GRANT,
            starts_at=now,
            ends_at=ends_at,
            reason=reason[:200],
        )
        audit.record(
            actor_type="staff",
            actor_id=actor_id,
            role=actor_role,
            action="entitlement.grant",
            target_type="account",
            target_id=account.id,
            reason=reason,
            metadata={"entitlement_id": str(ent.id), "ends_at": ends_at.isoformat()},
        )
        events.publish(EntitlementChanged(account_id=account.id, reason="grant"))
    return ent


def revoke(
    *,
    entitlement: Entitlement,
    reason: str,
    actor_type: str,
    actor_id: uuid.UUID | None,
    actor_role: str = "",
) -> None:
    """Revoke a window (refund, abuse). Audited. Never deletes the row."""
    with transaction.atomic():
        if entitlement.revoked_at is None:
            entitlement.revoked_at = timezone.now()
            entitlement.save(update_fields=["revoked_at", "updated_at"])
            audit.record(
                actor_type=actor_type,
                actor_id=actor_id,
                role=actor_role,
                action="entitlement.revoke",
                target_type="account",
                target_id=entitlement.account_id,
                reason=reason,
                metadata={"entitlement_id": str(entitlement.id)},
            )
            events.publish(EntitlementChanged(account_id=entitlement.account_id, reason="revoked"))

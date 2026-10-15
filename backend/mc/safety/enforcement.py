"""Moderation actions and appeals (MC-087, MC-088). Every action is audited; suspended members are signed out."""

import uuid
from datetime import timedelta

from django.conf import settings
from django.db import transaction
from django.utils import timezone

from mc.accounts import constants as account_status
from mc.accounts import selectors as account_selectors
from mc.accounts import services as account_services
from mc.audit import services as audit
from mc.common import events
from mc.common.errors import Conflict, Forbidden, NotFound, ValidationFailed
from mc.interests import services as interest_services
from mc.messaging import services as messaging_services
from mc.notifications import services as notification_services
from mc.profiles import services as profile_services
from mc.verification import selectors as verification_selectors

from .events import EnforcementApplied
from .models import Action, Ban, Case, EnforcementAppeal, Report


def _audit(
    actor_id: uuid.UUID | None,
    role: str,
    action: str,
    subject_id: uuid.UUID,
    reason: str,
    **meta: object,
) -> None:
    audit.record(
        actor_type="staff" if actor_id else "system",
        actor_id=actor_id,
        role=role,
        action=action,
        target_type="account",
        target_id=subject_id,
        reason=reason,
        metadata={k: str(v) for k, v in meta.items()},
    )


def take_action(
    *,
    subject_id: uuid.UUID,
    kind: str,
    actor_id: uuid.UUID,
    actor_role: str,
    reason: str,
    case_id: uuid.UUID | None = None,
    report_id: uuid.UUID | None = None,
    close_case: bool = False,
) -> Action:
    """Apply `kind` to the subject. `hide_content` needs `report_id` (which piece of content)."""
    if kind not in Action.Kind.values:
        raise ValidationFailed("Unknown action.")
    if not reason.strip():
        raise ValidationFailed("A reason is required.")
    account = account_selectors.get_account(subject_id)
    if account is None:
        raise NotFound()
    now = timezone.now()
    with transaction.atomic():
        case = Case.objects.select_for_update().filter(id=case_id).first() if case_id else None
        expires = (
            now + timedelta(days=settings.SUSPENSION_DAYS)
            if kind == Action.Kind.SUSPEND_7D
            else None
        )
        action = Action.objects.create(
            case=case,
            subject_id=subject_id,
            kind=kind,
            actor_id=actor_id,
            reason=reason[:500],
            expires_at=expires,
        )
        if kind == Action.Kind.WARN:
            notification_services.notify(
                account_id=subject_id, type="warning", payload={"action_id": action.id}
            )
        elif kind == Action.Kind.HIDE_CONTENT:
            _hide_content(report_id, subject_id)
        elif kind in (Action.Kind.SUSPEND_7D, Action.Kind.BAN):
            account_services.set_status(
                account=account, status=account_status.SUSPENDED
            )  # also signs out
            profile_services.suspend_profile(account_id=subject_id)
            if kind == Action.Kind.BAN:
                identity = verification_selectors.identity_hmac(account)
                if identity is not None:
                    Ban.objects.get_or_create(
                        identity_hmac=identity,
                        defaults={"account": account, "reason": reason[:500]},
                    )
        elif kind == Action.Kind.REINSTATE:
            _lift(account, subject_id)
        if case is not None:
            Report.objects.filter(case=case, status=Report.Status.OPEN).update(
                status=Report.Status.ACTIONED
                if kind != Action.Kind.REINSTATE
                else Report.Status.DISMISSED
            )
            if close_case:
                case.status, case.closed_at, case.resolution = Case.Status.CLOSED, now, kind
                case.save(update_fields=["status", "closed_at", "resolution", "updated_at"])
        _audit(
            actor_id,
            actor_role,
            f"safety.{kind}",
            subject_id,
            reason,
            action_id=action.id,
            case_id=case_id or "",
        )
        events.publish(EnforcementApplied(subject_id=subject_id, action_id=action.id, kind=kind))
    return action


def _hide_content(report_id: uuid.UUID | None, subject_id: uuid.UUID) -> None:
    report = (
        Report.objects.filter(id=report_id, subject_id=subject_id).first() if report_id else None
    )
    if report is None:
        raise ValidationFailed("hide_content needs the report whose content should be hidden.")
    if report.context_type == Report.ContextType.MESSAGE and report.context_id:
        messaging_services.hide_message(message_id=report.context_id)
    elif report.context_type == Report.ContextType.INTEREST and report.context_id:
        interest_services.cancel_interest(interest_id=report.context_id)
    else:
        profile_services.suspend_profile(
            account_id=subject_id
        )  # profile content hidden until reinstated


def _lift(account, subject_id: uuid.UUID) -> None:  # type: ignore[no-untyped-def]
    now = timezone.now()
    Action.objects.filter(
        subject_id=subject_id,
        kind__in=[Action.Kind.SUSPEND_7D, Action.Kind.BAN],
        lifted_at__isnull=True,
    ).update(lifted_at=now)
    identity = verification_selectors.identity_hmac(account)
    if identity is not None:
        Ban.objects.filter(identity_hmac=identity).delete()
    verified = verification_selectors.is_verified_adult(account)
    account_services.set_status(
        account=account,
        status=account_status.ACTIVE if verified else account_status.PENDING_VERIFICATION,
    )
    profile_services.restore_profile(account_id=subject_id)


def lift_expired_suspensions(*, now=None) -> int:  # type: ignore[no-untyped-def]
    """Beat job (idempotent): end `suspend_7d` actions whose time is up. Bans never expire."""
    now = now or timezone.now()
    n = 0
    for action in Action.objects.filter(
        kind=Action.Kind.SUSPEND_7D, lifted_at__isnull=True, expires_at__lte=now
    ):
        with transaction.atomic():
            account = account_selectors.get_account(action.subject_id)
            if account is not None and account.status == account_status.SUSPENDED:
                still = Action.objects.filter(
                    subject_id=action.subject_id, kind=Action.Kind.BAN, lifted_at__isnull=True
                ).exists()
                if not still:
                    _lift(account, action.subject_id)
            Action.objects.filter(id=action.id).update(lifted_at=now)
            _audit(
                None,
                "system",
                "safety.suspension_expired",
                action.subject_id,
                "suspension period ended",
                action_id=action.id,
            )
        n += 1
    return n


def enforcement_status(account) -> dict[str, object] | None:  # type: ignore[no-untyped-def]
    """What a restricted member is shown: the active action (kind, end date) and whether they can appeal."""
    action = (
        Action.objects.filter(
            subject_id=account.id,
            kind__in=[Action.Kind.SUSPEND_7D, Action.Kind.BAN],
            lifted_at__isnull=True,
        )
        .order_by("-id")
        .first()
    )
    if action is None:
        return None
    return {
        "action_id": str(action.id),
        "kind": action.kind,
        "expires_at": action.expires_at,
        "appeal_available": not EnforcementAppeal.objects.filter(action=action).exists(),
    }


# ----------------------------------------------------------------------------- MC-088
def open_appeal(*, account, action_id: uuid.UUID, message: str) -> EnforcementAppeal:  # type: ignore[no-untyped-def]
    """One appeal per action. The action must be about the caller and still in force or recent."""
    message = message.strip()
    if not 10 <= len(message) <= 1000:
        raise ValidationFailed("Please explain in 10-1,000 characters.")
    action = Action.objects.filter(id=action_id, subject=account).first()
    if action is None or action.kind == Action.Kind.REINSTATE:
        raise NotFound()
    existing = EnforcementAppeal.objects.filter(action=action).first()
    if existing is not None:
        raise Conflict("You've already appealed this decision.", appeal_id=str(existing.id))
    appeal = EnforcementAppeal.objects.create(action=action, account=account, message=message)
    _audit(
        None,
        "member",
        "safety.appeal_opened",
        account.id,
        "member appeal",
        appeal_id=appeal.id,
        action_id=action.id,
    )
    return appeal


def decide_appeal(
    *, appeal_id: uuid.UUID, reviewer_id: uuid.UUID, reviewer_role: str, uphold: bool, reason: str
) -> EnforcementAppeal:
    """A reviewer other than the one who took the action decides. Upheld → the action is overturned."""
    if not reason.strip():
        raise ValidationFailed("A reason is required.")
    with transaction.atomic():
        appeal = (
            EnforcementAppeal.objects.select_for_update()
            .select_related("action")
            .filter(id=appeal_id)
            .first()
        )
        if appeal is None:
            raise NotFound()
        if appeal.status != EnforcementAppeal.Status.OPEN:
            raise Conflict("This appeal was already decided.")
        if appeal.action.actor_id == reviewer_id:
            raise Forbidden("A different reviewer must decide this appeal.")
        appeal.status = (
            EnforcementAppeal.Status.UPHELD if uphold else EnforcementAppeal.Status.REJECTED
        )
        appeal.decided_by, appeal.decided_at, appeal.decision_reason = (
            reviewer_id,
            timezone.now(),
            reason[:500],
        )
        appeal.save(
            update_fields=["status", "decided_by", "decided_at", "decision_reason", "updated_at"]
        )
        if uphold:
            account = account_selectors.get_account(appeal.account_id)
            if account is not None and appeal.action.kind in (
                Action.Kind.SUSPEND_7D,
                Action.Kind.BAN,
            ):
                _lift(account, appeal.account_id)
        _audit(
            reviewer_id,
            reviewer_role,
            "safety.appeal_decided",
            appeal.account_id,
            reason,
            appeal_id=appeal.id,
            upheld=uphold,
        )
        notification_services.notify(
            account_id=appeal.account_id,
            type="appeal_decided",
            payload={"appeal_id": appeal.id, "upheld": str(uphold).lower()},
        )
    return appeal

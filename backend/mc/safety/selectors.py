import uuid

from django.db.models import Q

from .models import Block


def blocked_either_way_ids(account_id: uuid.UUID) -> set[uuid.UUID]:
    """Every account that blocked `account_id` or was blocked by them."""
    rows = Block.objects.filter(Q(blocker_id=account_id) | Q(blocked_id=account_id)).values_list(
        "blocker_id", "blocked_id"
    )
    out: set[uuid.UUID] = set()
    for a, b in rows:
        out.add(b if a == account_id else a)
    return out


def is_blocked_either_way(a: uuid.UUID, b: uuid.UUID) -> bool:
    return Block.objects.filter(
        Q(blocker_id=a, blocked_id=b) | Q(blocker_id=b, blocked_id=a)
    ).exists()


def contact_details_reason(text: str) -> str | None:
    """Reason a chat message must be blocked while the early-match contact window is open, else None."""
    from . import text_rules

    return text_rules.contact_reason(text)


def scam_flag(text: str) -> str | None:
    """Heuristic scam signal for a chat message (flag + safety tip for the recipient; never blocks)."""
    from . import text_rules

    return text_rules.scam_reason(text)


def blocked_members(account_id: uuid.UUID):  # type: ignore[no-untyped-def]
    """Blocks made BY `account_id` (what the blocker sees in their 'Blocked members' list)."""
    return Block.objects.filter(blocker_id=account_id).order_by("-id")


def is_identity_banned(identity_hmac: bytes) -> bool:
    """True if a verified person (keyed ID-number hash) was banned — they can't start over on a new phone."""
    from .models import Ban

    return Ban.objects.filter(identity_hmac=identity_hmac).exists()


def open_cases(*, severity: str | None = None):  # type: ignore[no-untyped-def]
    """The moderation queue: open cases, most urgent first (severity, then SLA due date)."""
    from .models import Case

    qs = Case.objects.filter(status="open").select_related("subject")
    if severity:
        qs = qs.filter(severity=severity)
    return qs.order_by("severity", "sla_due_at", "id")


def sla_breached(*, now=None):  # type: ignore[no-untyped-def]
    from django.utils import timezone

    from .models import Case

    return Case.objects.filter(status="open", sla_due_at__lt=now or timezone.now()).order_by(
        "sla_due_at"
    )


def has_deletion_hold(account_id: uuid.UUID) -> str:
    """Reason hard deletion must wait (open safety case or enforcement in force), else ''."""
    from .models import Action, Case

    if Case.objects.filter(subject_id=account_id, status="open").exists():
        return "open_safety_case"
    if Action.objects.filter(
        subject_id=account_id, kind__in=["suspend_7d", "ban"], lifted_at__isnull=True
    ).exists():
        return "enforcement_in_force"
    return ""


def export_for_account(account) -> dict[str, object]:  # type: ignore[no-untyped-def]
    from .models import Action, Report

    return {
        "reports_filed": [
            {
                "category": r.category,
                "context": r.context_type,
                "note": r.text,
                "at": r.created_at.isoformat(),
            }
            for r in Report.objects.filter(reporter=account).order_by("id")
        ],
        "enforcement_actions": [
            {
                "kind": a.kind,
                "at": a.created_at.isoformat(),
                "expires_at": a.expires_at.isoformat() if a.expires_at else None,
            }
            for a in Action.objects.filter(subject=account).order_by("id")
        ],
        "blocked_count": len(blocked_either_way_ids(account.id))
        and Block.objects.filter(blocker=account).count(),
    }

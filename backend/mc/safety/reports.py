"""Reports with evidence capture and case routing (MC-086)."""

import logging
import uuid
from datetime import timedelta
from typing import TYPE_CHECKING

from django.conf import settings
from django.db import IntegrityError, transaction
from django.utils import timezone

from mc.common import events, ratelimit
from mc.common.errors import NotFound, ValidationFailed
from mc.interests import selectors as interest_selectors
from mc.messaging import selectors as messaging_selectors
from mc.profiles import selectors as profile_selectors

from . import services
from .events import ReportCreated
from .models import Case, Report, ReportEvidence

if TYPE_CHECKING:
    from mc.accounts.models import Account

logger = logging.getLogger(__name__)

SEVERITY = {
    "threat": "s1", "underage": "s1",
    "scam": "s2", "financial_request": "s2", "impersonation": "s2", "married_concealed": "s2",
    "harassment": "s3", "sexual_content": "s3", "fake_profile": "s3",
}  # fmt: skip


def severity_for(category: str) -> str:
    return SEVERITY.get(category, "s4")


def _worse(a: str, b: str) -> str:
    return min(a, b)  # "s1" < "s2" < ... lexicographically: smaller = more severe


def report(
    *,
    reporter: "Account",
    subject_profile_id: uuid.UUID,
    category: str,
    context_type: str,
    context_id: uuid.UUID | None,
    text: str = "",
    also_block: bool = False,
    idempotency_key: str,
) -> tuple[Report, bool]:
    """File a report. Evidence is copied now (reported message + up to 20 prior; interest snapshot; profile
    snapshot). Severity comes from the category; the report joins (or opens) the subject's case with an SLA."""
    existing = Report.objects.filter(reporter=reporter, idempotency_key=idempotency_key).first()
    if existing:
        return existing, False
    if category not in Report.Category.values or context_type not in Report.ContextType.values:
        raise ValidationFailed("Unknown category or context.")
    text = text.strip()
    if len(text) > 1000:
        raise ValidationFailed("Please keep your note under 1,000 characters.")
    subject_id = profile_selectors.account_id_for_profile(subject_profile_id)
    if subject_id is None or subject_id == reporter.id:
        raise NotFound() if subject_id is None else ValidationFailed("You can't report yourself.")
    ratelimit.hit(f"report:{reporter.id}", limit=settings.REPORTS_PER_DAY, window_seconds=86400)

    evidence: list[tuple[str, dict]] = []
    if context_type == Report.ContextType.MESSAGE:
        if context_id is None:
            raise ValidationFailed("context_id is required for a message report.")
        rows = messaging_selectors.evidence_for_report(
            message_id=context_id,
            reporter_id=reporter.id,
            subject_id=subject_id,
            prior=settings.REPORT_EVIDENCE_MESSAGES,
        )
        if rows is None:
            raise NotFound()
        evidence = [("message", r) for r in rows]
    elif context_type == Report.ContextType.INTEREST:
        if context_id is None:
            raise ValidationFailed("context_id is required for an interest report.")
        snap = interest_selectors.evidence_for_report(
            interest_id=context_id, reporter_id=reporter.id, subject_id=subject_id
        )
        if snap is None:
            raise NotFound()
        evidence = [("interest_snapshot", snap)]
    else:
        context_id = subject_profile_id
    profile_snapshot = profile_selectors.report_snapshot(subject_profile_id)
    if profile_snapshot is not None:
        evidence.append(("profile_snapshot", profile_snapshot))

    import json

    now = timezone.now()
    sev = severity_for(category)
    try:
        with transaction.atomic():
            case = (
                Case.objects.select_for_update()
                .filter(subject_id=subject_id, status=Case.Status.OPEN)
                .first()
            )
            due = now + timedelta(hours=settings.SAFETY_SLA_HOURS[sev])
            if case is None:
                case = Case.objects.create(subject_id=subject_id, severity=sev, sla_due_at=due)
            elif _worse(sev, case.severity) != case.severity:
                case.severity, case.sla_due_at = sev, min(case.sla_due_at, due)
                case.save(update_fields=["severity", "sla_due_at", "updated_at"])
            rep = Report.objects.create(
                reporter=reporter, subject_id=subject_id, category=category, context_type=context_type,
                context_id=context_id, text=text or None, severity=sev, case=case, idempotency_key=idempotency_key,
            )  # fmt: skip
            ReportEvidence.objects.bulk_create(
                ReportEvidence(report=rep, kind=kind, position=i, content=json.dumps(content))
                for i, (kind, content) in enumerate(evidence)
            )
            if also_block:
                services.block(blocker=reporter, blocked_id=subject_id)
            events.publish(ReportCreated(report_id=rep.id, severity=sev, category=category))
    except IntegrityError:
        found = Report.objects.filter(reporter=reporter, idempotency_key=idempotency_key).first()
        if found is None:
            raise
        return found, False
    if sev == "s1":
        logger.warning(
            "s1 safety report created", extra={"alert": "s1_report", "report_id": str(rep.id)}
        )
    return rep, True

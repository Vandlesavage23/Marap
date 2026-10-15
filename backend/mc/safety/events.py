import uuid
from dataclasses import dataclass

from mc.common.events import DomainEvent


@dataclass(frozen=True)
class UserBlocked(DomainEvent):
    """Analytics/notification side effects only — visibility effects already ran in the block transaction."""

    blocker_id: uuid.UUID
    blocked_id: uuid.UUID


@dataclass(frozen=True)
class ReportCreated(DomainEvent):
    report_id: uuid.UUID
    severity: str
    category: str


@dataclass(frozen=True)
class EnforcementApplied(DomainEvent):
    subject_id: uuid.UUID
    action_id: uuid.UUID
    kind: str

import uuid
from dataclasses import dataclass

from mc.common.events import DomainEvent


@dataclass(frozen=True)
class EntitlementChanged(DomainEvent):
    account_id: uuid.UUID
    reason: str  # trial_started | purchase | grant | revoked


@dataclass(frozen=True)
class TrialReminderDue(DomainEvent):
    account_id: uuid.UUID
    kind: str  # ending_soon | ended

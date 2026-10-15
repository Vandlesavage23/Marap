import uuid
from dataclasses import dataclass

from mc.common.events import DomainEvent


@dataclass(frozen=True)
class AccountVerified(DomainEvent):
    account_id: uuid.UUID
    attempt_id: uuid.UUID


@dataclass(frozen=True)
class SafetyFlagRaised(DomainEvent):
    """Verification found something safety/trust should review (underage, duplicate identity)."""

    account_id: uuid.UUID
    attempt_id: uuid.UUID
    flag: str

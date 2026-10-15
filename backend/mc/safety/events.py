import uuid
from dataclasses import dataclass

from mc.common.events import DomainEvent


@dataclass(frozen=True)
class UserBlocked(DomainEvent):
    """Analytics/notification side effects only — visibility effects already ran in the block transaction."""

    blocker_id: uuid.UUID
    blocked_id: uuid.UUID

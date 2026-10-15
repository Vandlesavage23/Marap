import uuid
from dataclasses import dataclass

from mc.common.events import DomainEvent


@dataclass(frozen=True)
class MatchCreated(DomainEvent):
    match_id: uuid.UUID
    user_a: uuid.UUID
    user_b: uuid.UUID


@dataclass(frozen=True)
class MatchEnded(DomainEvent):
    match_id: uuid.UUID
    user_a: uuid.UUID
    user_b: uuid.UUID
    reason: str  # unmatched | blocked | deleted

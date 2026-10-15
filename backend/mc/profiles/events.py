import uuid
from dataclasses import dataclass

from mc.common.events import DomainEvent


@dataclass(frozen=True)
class ProfileWentLive(DomainEvent):
    account_id: uuid.UUID
    profile_id: uuid.UUID


@dataclass(frozen=True)
class ProfileWentOffline(DomainEvent):
    account_id: uuid.UUID
    profile_id: uuid.UUID
    reason: str

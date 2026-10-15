import uuid
from dataclasses import dataclass

from mc.common.events import DomainEvent


@dataclass(frozen=True)
class InterestSent(DomainEvent):
    interest_id: uuid.UUID
    sender_id: uuid.UUID
    recipient_id: uuid.UUID

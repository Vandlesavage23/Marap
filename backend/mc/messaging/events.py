import uuid
from dataclasses import dataclass

from mc.common.events import DomainEvent


@dataclass(frozen=True)
class MessageCreated(DomainEvent):
    message_id: uuid.UUID
    match_id: uuid.UUID
    sender_id: uuid.UUID | None
    recipient_id: uuid.UUID | None  # None for system messages (both members get them)
    kind: str


@dataclass(frozen=True)
class MessageRead(DomainEvent):
    match_id: uuid.UUID
    reader_id: uuid.UUID
    up_to_message_id: uuid.UUID

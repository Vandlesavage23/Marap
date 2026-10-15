import uuid
from dataclasses import dataclass

from mc.common.events import DomainEvent


@dataclass(frozen=True)
class AnswersSaved(DomainEvent):
    account_id: uuid.UUID

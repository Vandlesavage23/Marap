import uuid
from dataclasses import dataclass
from typing import Protocol

from mc.phase5 import gate


@dataclass(frozen=True)
class DueDiligenceRequest:
    requester_id: uuid.UUID
    subject_id: uuid.UUID
    kind: str


class DueDiligenceService(Protocol):
    def request_check(self, request: DueDiligenceRequest) -> uuid.UUID: ...


class DisabledDueDiligenceService:
    """The only implementation: every call raises `NotEnabled`."""

    def request_check(self, request: DueDiligenceRequest) -> uuid.UUID:
        gate.require_enabled(gate.DUE_DILIGENCE)
        raise gate.NotEnabled()


def get_service() -> DueDiligenceService:
    return DisabledDueDiligenceService()

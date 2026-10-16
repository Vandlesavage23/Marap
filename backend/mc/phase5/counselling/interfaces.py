import uuid
from datetime import datetime
from typing import Protocol

from mc.phase5 import gate


class Provider(Protocol):
    id: uuid.UUID
    display_name: str
    verified: bool


class Appointment(Protocol):
    id: uuid.UUID
    provider_id: uuid.UUID
    member_id: uuid.UUID
    starts_at: datetime
    status: str


class CounsellingService(Protocol):
    def list_providers(self) -> list[Provider]: ...

    def book(
        self, *, member_id: uuid.UUID, provider_id: uuid.UUID, starts_at: datetime
    ) -> Appointment: ...


class DisabledCounsellingService:
    """The only implementation: every call raises `NotEnabled`."""

    def list_providers(self) -> list[Provider]:
        gate.require_enabled(gate.COUNSELLING)
        raise gate.NotEnabled()

    def book(
        self, *, member_id: uuid.UUID, provider_id: uuid.UUID, starts_at: datetime
    ) -> Appointment:
        gate.require_enabled(gate.COUNSELLING)
        raise gate.NotEnabled()


def get_service() -> CounsellingService:
    return DisabledCounsellingService()

import uuid
from dataclasses import dataclass

from mc.common.events import DomainEvent


@dataclass(frozen=True)
class NewDeviceSignIn(DomainEvent):
    """An existing account signed in / registered from an unseen device (push alert: MC-078)."""

    account_id: uuid.UUID
    device_id: uuid.UUID

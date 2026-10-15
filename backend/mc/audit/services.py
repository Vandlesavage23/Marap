import uuid
from typing import Any

from mc.common.crypto import hmac_value

from .models import AuditEvent


def record(
    *,
    actor_type: str,
    action: str,
    actor_id: uuid.UUID | None = None,
    role: str = "",
    target_type: str = "",
    target_id: uuid.UUID | None = None,
    reason: str = "",
    metadata: dict[str, Any] | None = None,
    ip: str | None = None,
) -> AuditEvent:
    """Write one append-only audit event. Call inside the caller's transaction so the audit row
    commits or rolls back together with the action it describes."""
    return AuditEvent.objects.create(
        actor_type=actor_type,
        actor_id=actor_id,
        role=role,
        action=action,
        target_type=target_type,
        target_id=target_id,
        reason=reason[:500],
        metadata=metadata or {},
        ip_hmac=hmac_value(ip, purpose="ip") if ip else None,
    )

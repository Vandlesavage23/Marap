"""Changing feature flags (Bible §17, §12.4 `config.flags`): staff id + role are required and re-checked here,
every change is audited, and the cache is invalidated when the change commits."""

import uuid

from django.db import IntegrityError, transaction

from mc.audit import services as audit
from mc.common.errors import Forbidden, ValidationFailed

from . import registry, selectors
from .models import FeatureFlag

FLAG_ROLES = frozenset(
    {"engineer_oncall", "superadmin"}
)  # roles holding `config.flags` (adminportal.policies)


def set_flag(
    *,
    key: str,
    enabled: bool,
    staff_id: uuid.UUID,
    role: str,
    reason: str,
    ip: str | None = None,
) -> tuple[FeatureFlag, bool]:
    """Set a flag override. A reason is required (it goes into the audit row). Returns `(flag, changed)`; setting
    the current value again is a no-op (no audit row)."""
    if role not in FLAG_ROLES:
        raise Forbidden("Your role can't change feature flags.")
    if not registry.is_known(key):
        raise ValidationFailed("Unknown feature flag.")
    if enabled and key in registry.LOCKED_OFF:
        raise Forbidden("This feature is not built yet and can't be switched on.")
    reason = reason.strip()
    if not reason:
        raise ValidationFailed("A reason is required.")
    with transaction.atomic():
        flag = FeatureFlag.objects.select_for_update().filter(key=key).first()
        before = flag.enabled if flag else registry.default_for(key)
        if before == enabled:  # nothing to do; don't create an override that nobody asked for
            return flag or FeatureFlag(key=key, enabled=enabled), False
        if flag is None:
            flag = _create_locked(key, default=before)
            before = flag.enabled
            if before == enabled:  # another admin set it to the same value a moment ago
                return flag, False
        flag.enabled = enabled
        flag.updated_by = staff_id
        if not flag.description:
            flag.description = registry.description_for(key)
        flag.save(update_fields=["enabled", "updated_by", "description", "updated_at"])
        audit.record(
            actor_type="staff", actor_id=staff_id, role=role, action="config.flag_set",
            target_type="feature_flag", target_id=flag.id, reason=reason, ip=ip,
            metadata={"key": key, "from": before, "to": enabled},
        )  # fmt: skip
        # Drop the cache now and again on commit: a reader may refill it from the old row before we commit.
        selectors.invalidate()
        transaction.on_commit(selectors.invalidate)
    return flag, True


def _create_locked(key: str, *, default: bool) -> FeatureFlag:
    """Create the override row at its current effective value and lock it; if two admins race on a new key the
    loser picks up the winner's row."""
    try:
        with transaction.atomic():
            return FeatureFlag.objects.create(key=key, enabled=default)
    except IntegrityError:
        return FeatureFlag.objects.select_for_update().get(key=key)

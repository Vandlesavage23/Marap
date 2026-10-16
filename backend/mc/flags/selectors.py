"""Cached flag reads. Order: Redis (30 s) -> database -> `settings.FEATURE_FLAGS_DEFAULT`. A cache or database
outage degrades to the defaults; it never raises into the caller (a flag check must not take a feature down)."""

import json
import logging
from typing import Any

from django.conf import settings

from mc.common.redis import get_redis

from . import registry
from .models import FeatureFlag

log = logging.getLogger("mc.flags")

CACHE_KEY = "mc:flags:overrides:v1"
CACHE_TTL_SECONDS = 30


def _cache_get() -> dict[str, bool] | None:
    try:
        raw = get_redis().get(CACHE_KEY)
    except Exception:
        log.warning("flag cache unavailable (read)")
        return None
    if raw is None:
        return None
    try:
        data = json.loads(raw)
    except ValueError:
        return None
    if isinstance(data, dict):
        return {str(k): bool(v) for k, v in data.items()}
    return None


def _cache_put(overrides: dict[str, bool]) -> None:
    try:
        get_redis().set(CACHE_KEY, json.dumps(overrides), ex=CACHE_TTL_SECONDS)
    except Exception:
        log.warning("flag cache unavailable (write)")


def invalidate() -> None:
    """Drop the cached overrides (called after a flag change commits)."""
    try:
        get_redis().delete(CACHE_KEY)
    except Exception:
        log.warning(
            "flag cache unavailable (invalidate); entries expire within %ss", CACHE_TTL_SECONDS
        )


def overrides() -> dict[str, bool]:
    """Every database override, `{key: enabled}`; empty if both cache and database are unreachable."""
    cached = _cache_get()
    if cached is not None:
        return cached
    try:
        rows = dict(FeatureFlag.objects.values_list("key", "enabled"))
    except Exception:
        log.warning("flag table unavailable; using settings defaults")
        return {}
    _cache_put(rows)
    return rows


def flag_enabled(key: str) -> bool:
    """Is the flag on? Locked-off flags are always off. Unknown keys are off."""
    if key in registry.LOCKED_OFF:
        return False
    found = overrides()
    if key in found:
        return found[key]
    return registry.default_for(key)


def public_flags() -> dict[str, bool]:
    """The non-sensitive flags the app may read (no sign-in needed)."""
    return {k: flag_enabled(k) for k in registry.PUBLIC_FLAGS}


def all_flags() -> list[dict[str, Any]]:
    """Every known flag with its effective value and where it came from (for the staff page). Reads the
    database directly so staff never see a stale cache."""
    rows = {f.key: f for f in FeatureFlag.objects.all()}
    keys = sorted(set(settings.FEATURE_FLAGS_DEFAULT) | set(rows))
    out = []
    for key in keys:
        row = rows.get(key)
        locked = key in registry.LOCKED_OFF
        out.append(
            {
                "key": key,
                "enabled": False if locked else (row.enabled if row else registry.default_for(key)),
                "source": "locked" if locked else ("override" if row else "default"),
                "default": registry.default_for(key),
                "description": (
                    row.description if row and row.description else registry.description_for(key)
                ),
                "updated_by": row.updated_by if row else None,
                "updated_at": row.updated_at if row else None,
                "locked": locked,
            }
        )
    return out

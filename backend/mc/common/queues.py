"""Celery queue depth and age, read straight from the Redis broker (Bible §15; alert `queue_age_high`).

Every task message is stamped with its publish time in a header (`mc_enqueued_at`, set by a
`before_task_publish` handler registered in `CommonConfig.ready`). Kombu's Redis transport LPUSHes and
BRPOPs, so the *oldest* message is the last list element: age = now - header of `LINDEX queue -1`.
Messages published before the stamp existed (or by another publisher) have no header; they count towards
depth but yield no age. Nothing here reads message bodies.
"""

import json
import time
from collections.abc import Iterable
from typing import Any, Protocol

from django.conf import settings

ENQUEUED_HEADER = "mc_enqueued_at"
DEFAULT_QUEUES = ("default", "media", "billing", "notify")


class RedisLike(Protocol):
    def llen(self, name: str) -> int: ...
    def lindex(self, name: str, index: int) -> Any: ...


def stamp_enqueued(headers: dict[str, Any] | None = None, **_: Any) -> None:
    """`before_task_publish` handler: record when the message was published."""
    if headers is not None:
        headers[ENQUEUED_HEADER] = time.time()


def _oldest_enqueued_at(raw: Any) -> float | None:
    if raw is None:
        return None
    try:
        message = json.loads(raw)
        value = message["headers"][ENQUEUED_HEADER]
        return float(value)
    except (ValueError, KeyError, TypeError):
        return None


def queue_stats(
    redis_client: RedisLike, queues: Iterable[str] = DEFAULT_QUEUES, *, now: float | None = None
) -> dict[str, tuple[int, float]]:
    """`{queue: (depth, oldest_age_seconds)}`; age is 0.0 for an empty queue or unstamped message."""
    now = time.time() if now is None else now
    out: dict[str, tuple[int, float]] = {}
    for q in queues:
        depth = int(redis_client.llen(q))
        enqueued = _oldest_enqueued_at(redis_client.lindex(q, -1)) if depth else None
        out[q] = (depth, max(0.0, now - enqueued) if enqueued is not None else 0.0)
    return out


def configured_queues() -> tuple[str, ...]:
    return tuple(getattr(settings, "CELERY_MONITORED_QUEUES", DEFAULT_QUEUES))


def refresh_gauges(redis_client: RedisLike | None = None) -> dict[str, tuple[int, float]]:
    """Update the Prometheus queue gauges from the broker. Broker trouble must never break a scrape."""
    from . import metrics

    if redis_client is None:
        from .redis import get_redis

        redis_client = get_redis()
    try:
        stats = queue_stats(redis_client, configured_queues())
    except Exception:
        return {}
    for q, (depth, age) in stats.items():
        metrics.CELERY_QUEUE_DEPTH.labels(queue=q).set(depth)
        metrics.CELERY_QUEUE_AGE.labels(queue=q).set(age)
    return stats

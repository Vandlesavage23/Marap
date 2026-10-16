import logging

from celery import shared_task
from django.conf import settings

from . import metrics, queues
from .redis import get_redis

log = logging.getLogger(__name__)


def check_queue_age(
    redis_client: queues.RedisLike | None = None, *, now: float | None = None
) -> list[str]:
    """Emit one WARNING `alert=queue_age_high` per queue whose oldest waiting task is older than
    `QUEUE_AGE_ALERT_SECONDS` (default 300). Returns the offending queue names."""
    stats = queues.queue_stats(redis_client or get_redis(), queues.configured_queues(), now=now)
    offending = []
    for queue, (depth, age) in stats.items():
        metrics.CELERY_QUEUE_DEPTH.labels(queue=queue).set(depth)
        metrics.CELERY_QUEUE_AGE.labels(queue=queue).set(age)
        if age > settings.QUEUE_AGE_ALERT_SECONDS:
            offending.append(queue)
            metrics.count_alert("queue_age_high")
            log.warning(
                "celery queue backed up",
                extra={
                    "alert": "queue_age_high",
                    "queue": queue,
                    "depth": depth,
                    "oldest_age_seconds": int(age),
                    "threshold_seconds": settings.QUEUE_AGE_ALERT_SECONDS,
                },
            )
    return offending


@shared_task(queue="default")
def queue_age_check() -> list[str]:
    return check_queue_age()

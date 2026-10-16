import json
import logging

import pytest
from django.conf import settings

from mc.common import metrics, queues, tasks
from mc.common.redis import get_redis

NOW = 1_800_000_000.0


class FakeRedis:
    """Minimal list store: LPUSH semantics, oldest message at the right end."""

    def __init__(self, data: dict[str, list[str]]):
        self.data = data

    def llen(self, name):
        return len(self.data.get(name, []))

    def lindex(self, name, index):
        items = self.data.get(name, [])
        return items[index] if items else None


def msg(enqueued_at: float | None) -> str:
    headers = {"task": "mc.x"} | ({queues.ENQUEUED_HEADER: enqueued_at} if enqueued_at else {})
    return json.dumps({"body": "e30=", "headers": headers, "properties": {}})


def test_stats_report_depth_and_oldest_age():
    r = FakeRedis({"billing": [msg(NOW - 10), msg(NOW - 100), msg(NOW - 400)], "media": []})
    stats = queues.queue_stats(r, ["billing", "media", "missing"], now=NOW)
    assert stats == {"billing": (3, 400.0), "media": (0, 0.0), "missing": (0, 0.0)}


def test_unstamped_or_garbage_messages_count_for_depth_but_not_age():
    r = FakeRedis({"default": [msg(NOW - 5), msg(None)], "notify": ["not json"]})
    assert queues.queue_stats(r, ["default", "notify"], now=NOW) == {
        "default": (2, 0.0),
        "notify": (1, 0.0),
    }


def test_publish_handler_stamps_headers():
    h: dict = {}
    queues.stamp_enqueued(headers=h)
    assert isinstance(h[queues.ENQUEUED_HEADER], float)
    queues.stamp_enqueued(headers=None)  # tolerated


def test_real_celery_publish_carries_the_enqueue_stamp():
    """The signal is wired in CommonConfig.ready: a task published through Celery gets the header."""
    from celery import Celery
    from celery.signals import before_task_publish

    seen: dict = {}

    def capture(headers=None, **_):
        seen.update(headers or {})

    before_task_publish.connect(capture, weak=False)
    try:
        Celery("probe", broker="memory://").send_task("mc.billing.tasks.expire_purchases")
    finally:
        before_task_publish.disconnect(capture)
    assert isinstance(seen.get(queues.ENQUEUED_HEADER), float)


def test_alert_fires_only_for_queues_over_five_minutes(caplog):
    r = FakeRedis(
        {
            "default": [msg(NOW - 301)],
            "billing": [msg(NOW - 299)],
            "media": [msg(NOW - 2), msg(NOW - 3000)],
        }
    )
    with caplog.at_level(logging.WARNING):
        offending = tasks.check_queue_age(r, now=NOW)
    assert offending == ["default", "media"]
    recs = [x for x in caplog.records if getattr(x, "alert", "") == "queue_age_high"]
    assert {x.queue for x in recs} == {"default", "media"}
    media = next(x for x in recs if x.queue == "media")
    assert media.levelno == logging.WARNING
    assert media.depth == 2 and media.oldest_age_seconds == 3000 and media.threshold_seconds == 300


def test_no_alert_when_queues_are_healthy(caplog):
    with caplog.at_level(logging.WARNING):
        assert tasks.check_queue_age(FakeRedis({"default": [msg(NOW - 20)]}), now=NOW) == []
    assert not [x for x in caplog.records if getattr(x, "alert", "")]


def test_task_runs_against_real_redis_and_is_scheduled(caplog):
    sched = settings.CELERY_BEAT_SCHEDULE["queue-age-check"]
    assert sched["task"] == "mc.common.tasks.queue_age_check" and sched["schedule"] <= 60
    r = get_redis()
    r.lpush("default", msg(1.0))  # enqueued at the epoch: ancient
    try:
        with caplog.at_level(logging.WARNING):
            assert tasks.queue_age_check() == ["default"]
    finally:
        r.delete("default")
    assert any(getattr(x, "alert", "") == "queue_age_high" for x in caplog.records)


def test_refresh_gauges_sets_prometheus_values_and_swallows_broker_errors():
    queues.refresh_gauges(FakeRedis({"billing": [msg(1.0)] * 3}))
    assert metrics.REGISTRY.get_sample_value("mc_celery_queue_depth", {"queue": "billing"}) == 3

    class Broken:
        def llen(self, name):
            raise ConnectionError("redis down")

    assert queues.refresh_gauges(Broken()) == {}


@pytest.mark.parametrize("queue", ["default", "media", "billing", "notify"])
def test_every_configured_queue_is_monitored(queue):
    assert queue in queues.configured_queues()

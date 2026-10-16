import logging
from datetime import UTC, datetime, timedelta

import pytest
from django.test import override_settings
from freezegun import freeze_time

from mc.billing import selectors, services
from mc.billing.models import PaymentEvent

pytestmark = pytest.mark.django_db

NOON = datetime(2026, 3, 1, 12, 0, tzinfo=UTC)


def make_event(n: int, *, status: str = "failed", provider: str = "flutterwave") -> PaymentEvent:
    e, _ = services.ingest_event(
        provider=provider,
        provider_event_id=f"wh-{provider}-{n}",
        event_type="charge.completed",
        raw={"customer": {"phone": "+256772123456"}},
        normalized=None,
        signature_valid=True,
    )
    PaymentEvent.objects.filter(id=e.id).update(process_status=status)
    return e


def alerts(caplog):
    return [r for r in caplog.records if getattr(r, "alert", "") == "payment_webhook_failures"]


def test_more_than_five_failures_in_ten_minutes_alerts(caplog):
    with freeze_time(NOON):
        for i in range(6):
            make_event(i)
        with caplog.at_level(logging.WARNING):
            assert services.check_webhook_failures() == 6
    (rec,) = alerts(caplog)
    assert rec.levelno == logging.WARNING
    assert rec.count == 6 and rec.window_minutes == 10 and rec.threshold == 5
    assert rec.by_provider == {"flutterwave": 6}


def test_exactly_five_failures_does_not_alert(caplog):
    with freeze_time(NOON):
        for i in range(5):
            make_event(i)
        with caplog.at_level(logging.WARNING):
            assert services.check_webhook_failures() == 5
    assert alerts(caplog) == []


def test_old_failures_age_out_of_the_window(caplog):
    with freeze_time(NOON):
        for i in range(6):
            make_event(i)
    with freeze_time(NOON + timedelta(minutes=10, seconds=1)), caplog.at_level(logging.WARNING):
        assert services.check_webhook_failures() == 0
    assert alerts(caplog) == []
    # ...but the same rows are still inside the window nine minutes later
    with freeze_time(NOON + timedelta(minutes=9)), caplog.at_level(logging.WARNING):
        assert services.check_webhook_failures() == 6
    assert len(alerts(caplog)) == 1


def test_only_failed_events_count_and_counts_are_per_provider():
    with freeze_time(NOON):
        for i in range(4):
            make_event(i, status="processed")
        make_event(10, provider="apple")
        make_event(11, provider="google")
        make_event(12, provider="google")
        make_event(13, status="ignored")
        assert selectors.failed_webhook_events(since=NOON - timedelta(minutes=10)) == {
            "apple": 1,
            "google": 2,
        }


@override_settings(PAYMENT_WEBHOOK_FAILURE_THRESHOLD=1)
def test_threshold_is_configurable(caplog):
    with freeze_time(NOON):
        make_event(1)
        make_event(2)
        with caplog.at_level(logging.WARNING):
            services.check_webhook_failures()
    assert len(alerts(caplog)) == 1


def test_alert_log_carries_no_pii(caplog):
    with freeze_time(NOON):
        for i in range(6):
            make_event(i)
        with caplog.at_level(logging.WARNING):
            services.check_webhook_failures()
    rendered = " ".join(f"{r.getMessage()} {r.__dict__}" for r in alerts(caplog))
    assert "256772" not in rendered and "phone" not in rendered


def test_task_is_scheduled_and_runs():
    from django.conf import settings

    from mc.billing import tasks

    sched = settings.CELERY_BEAT_SCHEDULE["billing-webhook-failure-check"]
    assert sched["task"] == "mc.billing.tasks.check_webhook_failures"
    assert sched["schedule"] <= 300  # at most half the 10 minute window
    assert tasks.check_webhook_failures() == 0

import json
import logging
import re
import uuid

import pytest
from django.test import Client, override_settings

from mc.common import metrics
from mc.common.metrics import REGISTRY

pytestmark = pytest.mark.django_db

TOKEN = "s3cret-metrics-token-value"
ADMIN = {"headers": {"host": "admin.mc.test"}}


def sample(name, **labels):
    return REGISTRY.get_sample_value(name, labels) or 0.0


def scrape(token=TOKEN):
    with override_settings(METRICS_TOKEN=TOKEN):
        return Client(**ADMIN).get("/metrics", headers={"Authorization": f"Bearer {token}"})


# ---- access control ------------------------------------------------------------
def test_metrics_requires_a_bearer_token():
    with override_settings(METRICS_TOKEN=TOKEN):
        c = Client(**ADMIN)
        r = c.get("/metrics")
        assert r.status_code == 401 and r["WWW-Authenticate"] == "Bearer"
        assert r["Content-Type"] == "application/problem+json"
        assert c.get("/metrics", headers={"Authorization": "Bearer wrong"}).status_code == 401
        assert c.get("/metrics", headers={"Authorization": f"Basic {TOKEN}"}).status_code == 401
        assert c.get("/metrics", headers={"Authorization": "Bearer "}).status_code == 401
        assert c.get("/metrics", headers={"Authorization": TOKEN}).status_code == 401
        assert c.post("/metrics").status_code == 401  # auth first, even for bad methods


def test_metrics_fails_closed_when_no_token_is_configured():
    with override_settings(METRICS_TOKEN=""):
        c = Client(**ADMIN)
        assert c.get("/metrics").status_code == 403
        # an empty bearer must not match an empty token
        assert c.get("/metrics", headers={"Authorization": "Bearer "}).status_code == 403
        assert c.get("/metrics", headers={"Authorization": "Bearer x"}).status_code == 403


def test_metrics_default_setting_is_disabled():
    from django.conf import settings

    assert settings.METRICS_TOKEN == ""  # test settings do not set it: closed by default


def test_metrics_is_not_served_on_the_public_api_or_pay_hosts():
    with override_settings(METRICS_TOKEN=TOKEN):
        for host in ("api.mc.test", "pay.mc.test"):
            r = Client(headers={"host": host}).get(
                "/metrics", headers={"Authorization": f"Bearer {TOKEN}"}
            )
            assert r.status_code == 404
        assert (
            Client(headers={"host": "api.mc.test"})
            .get("/api/v1/metrics", headers={"Authorization": f"Bearer {TOKEN}"})
            .status_code
            == 404
        )


def test_valid_token_returns_prometheus_text_and_only_get_head():
    r = scrape()
    assert r.status_code == 200
    assert r["Content-Type"].startswith("text/plain; version=0.0.4")
    assert r["Cache-Control"] == "no-store"
    body = r.content.decode()
    assert "# TYPE mc_http_requests_total counter" in body
    with override_settings(METRICS_TOKEN=TOKEN):
        r = Client(**ADMIN).post("/metrics", headers={"Authorization": f"Bearer {TOKEN}"})
    assert r.status_code == 405


# ---- request metrics ---------------------------------------------------------------
def test_request_counter_and_latency_increment_per_route_pattern(api):
    route = "api/v1/health"
    before = sample("mc_http_requests_total", method="GET", route=route, status="200")
    n_before = sample("mc_http_request_duration_seconds_count", method="GET", route=route)
    api.get("/api/v1/health")
    api.get("/api/v1/health")
    assert sample("mc_http_requests_total", method="GET", route=route, status="200") == before + 2
    assert (
        sample("mc_http_request_duration_seconds_count", method="GET", route=route) == n_before + 2
    )


def test_error_statuses_are_counted(api, monkeypatch):
    from django.db import connection

    monkeypatch.setattr(connection, "cursor", lambda: (_ for _ in ()).throw(RuntimeError("x")))
    before = sample("mc_http_requests_total", method="GET", route="api/v1/ready", status="503")
    assert api.get("/api/v1/ready").status_code == 503
    assert (
        sample("mc_http_requests_total", method="GET", route="api/v1/ready", status="503")
        == before + 1
    )


def test_labels_are_patterns_never_ids_or_pii():
    admin = Client(**ADMIN)
    aid = uuid.uuid4()
    admin.get(f"/users/{aid}/notes")  # not logged in: redirect/deny, still a routed request
    Client(headers={"host": "api.mc.test"}).get(f"/api/v1/nope/{aid}?phone=%2B256772123456")
    Client(headers={"host": "api.mc.test"}).get("/api/v1/health?email=jane@example.com")
    body = scrape().content.decode()
    assert str(aid) not in body
    assert "256772123456" not in body and "jane" not in body and "example.com" not in body
    routes = set(re.findall(r'route="([^"]*)"', body))
    assert "users/<uuid:account_id>/notes" in routes
    assert metrics.UNMATCHED_ROUTE in routes
    # every route label is either the sentinel or a registered URL pattern: no raw uuid or digits runs
    for r in routes:
        assert not re.search(r"[0-9a-f]{8}-[0-9a-f]{4}", r) and not re.search(r"\d{6,}", r)


def test_unknown_paths_collapse_into_one_label_so_cardinality_is_bounded(api):
    before = sample("mc_http_requests_total", method="GET", route="unmatched", status="404")
    for i in range(25):
        api.get(f"/api/v1/random-{i}")
    assert (
        sample("mc_http_requests_total", method="GET", route="unmatched", status="404")
        == before + 25
    )
    body = scrape().content.decode()
    assert "random-" not in body


def test_odd_http_methods_are_clamped():
    assert metrics.method_label("get") == "GET"
    assert metrics.method_label("BREW") == "other"
    assert metrics.method_label("X" * 500) == "other"


def test_access_log_has_route_status_duration_and_no_query_or_ids(api, caplog):
    with caplog.at_level(logging.INFO, logger="mc.access"):
        api.get("/api/v1/nope/12345678?token=abc&phone=0772123456")
    (rec,) = [r for r in caplog.records if r.name == "mc.access"]
    assert rec.route == "unmatched" and rec.status == 404 and rec.method == "GET"
    assert isinstance(rec.duration_ms, float)
    assert "12345678" not in json.dumps(rec.__dict__, default=str)
    assert "0772123456" not in json.dumps(rec.__dict__, default=str)


def test_probes_are_logged_at_debug_only(api, caplog):
    with caplog.at_level(logging.INFO, logger="mc.access"):
        api.get("/api/v1/health")
        api.get("/ready")
    assert [r for r in caplog.records if r.name == "mc.access"] == []


# ---- domain counters ------------------------------------------------------------------
def test_otp_prefix_label_is_prefix_only_and_bounded(monkeypatch):
    monkeypatch.setattr(metrics, "_otp_prefixes", set())
    assert metrics.otp_prefix_label("+256772123456") == "+256772"
    for i in range(metrics.MAX_OTP_PREFIXES + 20):
        metrics.otp_prefix_label(f"+{100000 + i}0000")
    assert metrics.otp_prefix_label("+999999999999") == "other"
    assert metrics.otp_prefix_label("+256772000000") == "+256772"  # known prefixes keep their label


def test_otp_send_increments_counter_without_leaking_the_number(api):
    from mc.accounts.providers.sms import FakeSms  # noqa: F401

    number = "+256772123456"
    before = sample("mc_otp_sends_total", prefix="+256772")
    r = api.post(
        "/api/v1/auth/otp/start",
        data=json.dumps({"phone": number, "purpose": "login"}),
        content_type="application/json",
    )
    assert r.status_code in (200, 202, 204), r.content
    assert sample("mc_otp_sends_total", prefix="+256772") == before + 1
    assert "256772123456" not in scrape().content.decode()


def test_report_volume_by_severity_counter():
    before = sample("mc_reports_total", severity="s1")
    metrics.count_report("s1")
    assert sample("mc_reports_total", severity="s1") == before + 1


def test_payment_event_counters_by_status():
    from mc.billing import services
    from mc.billing.tests.helpers import ev, new_account

    acct = new_account()
    received = sample("mc_payment_events_total", provider="apple", status="received")
    processed = sample("mc_payment_events_total", provider="apple", status="processed")
    failed = sample("mc_payment_events_total", provider="apple", status="failed")
    args = {
        "provider": "apple",
        "event_type": "grant",
        "raw": {},
        "normalized": ev("grant", acct=acct, start=0, end=30),
        "signature_valid": True,
    }
    e, _ = services.ingest_event(provider_event_id="m-1", **args)
    assert sample("mc_payment_events_total", provider="apple", status="received") == received + 1
    services.process_event(event_id=e.id)
    assert sample("mc_payment_events_total", provider="apple", status="processed") == processed + 1
    # a replay of an already-ingested event is not double counted
    services.ingest_event(provider_event_id="m-1", **args)
    assert sample("mc_payment_events_total", provider="apple", status="received") == received + 1
    # a failure (unknown product) is counted as failed
    bad = ev("grant", txn="t2", acct=acct, start=0, end=30, product="no_such_product")
    e2, _ = services.ingest_event(provider_event_id="m-2", **(args | {"normalized": bad}))
    services.process_event(event_id=e2.id)
    assert sample("mc_payment_events_total", provider="apple", status="failed") == failed + 1


def test_verification_outcome_counter_increments():
    before = sample("mc_verification_outcomes_total", outcome="passed")
    metrics.count_verification("passed")
    assert sample("mc_verification_outcomes_total", outcome="passed") == before + 1


def test_websocket_gauge_tracks_connect_and_disconnect():
    import asyncio

    from channels.testing import WebsocketCommunicator

    from mc.messaging.consumers import ChatConsumer

    async def run() -> tuple[float, float, float]:
        base = sample("mc_websocket_connections")
        comm = WebsocketCommunicator(ChatConsumer.as_asgi(), "/ws/chat")
        ok, _ = await comm.connect()
        assert ok
        during = sample("mc_websocket_connections")
        await comm.disconnect()
        return base, during, sample("mc_websocket_connections")

    base, during, after = asyncio.run(run())
    assert during == base + 1 and after == base


def test_alert_counter_exists():
    before = sample("mc_alerts_total", alert="queue_age_high")
    metrics.count_alert("queue_age_high")
    assert sample("mc_alerts_total", alert="queue_age_high") == before + 1


def test_metric_label_names_never_include_identifying_fields():
    forbidden = {
        "account",
        "account_id",
        "user",
        "user_id",
        "phone",
        "email",
        "token",
        "ip",
        "path",
        "url",
    }
    ours = [v for k, v in vars(metrics).items() if k.isupper() and hasattr(v, "_labelnames")]
    assert len(ours) >= 9
    for metric in ours:
        assert not (set(metric._labelnames) & forbidden), metric._name

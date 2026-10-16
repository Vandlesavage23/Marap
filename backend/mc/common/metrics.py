"""Prometheus metrics (Bible §15).

Cardinality and privacy rules (enforced by tests):
* `route` is the URL *pattern* (`api/v1/users/<uuid:account_id>/notes`), never the concrete path, so ids and
  other PII can never become label values. Requests that match no route share one `unmatched` label.
* `method` is clamped to the standard HTTP verbs; OTP prefix is the country code + network prefix only
  (`+256772`, never a number) and is capped, with overflow folded into `other`.
* No metric ever carries an account id, phone, email, token or free text.

Multi-process servers (gunicorn workers): set `PROMETHEUS_MULTIPROC_DIR` and the exporter aggregates the
per-process files; otherwise each process exposes its own registry.
"""

import os
import threading

from prometheus_client import (
    CollectorRegistry,
    Counter,
    Gauge,
    Histogram,
    generate_latest,
    multiprocess,
)
from prometheus_client.registry import REGISTRY

UNMATCHED_ROUTE = "unmatched"
OTHER = "other"
_METHODS = frozenset({"GET", "HEAD", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"})
MAX_OTP_PREFIXES = 64

HTTP_REQUESTS = Counter(
    "mc_http_requests_total",
    "HTTP requests by route pattern, method and status code.",
    ["method", "route", "status"],
)
HTTP_LATENCY = Histogram(
    "mc_http_request_duration_seconds",
    "HTTP request latency by route pattern and method.",
    ["method", "route"],
    buckets=(0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0),
)
WS_CONNECTIONS = Gauge(
    "mc_websocket_connections",
    "Currently open authenticated-or-pending WebSocket connections.",
    multiprocess_mode="livesum",
)
WS_CONNECTS = Counter("mc_websocket_connects_total", "WebSocket connections accepted.")
CELERY_QUEUE_DEPTH = Gauge(
    "mc_celery_queue_depth",
    "Messages waiting in a Celery queue.",
    ["queue"],
    multiprocess_mode="max",
)
CELERY_QUEUE_AGE = Gauge(
    "mc_celery_queue_oldest_age_seconds",
    "Age of the oldest message waiting in a Celery queue (0 when empty or unknown).",
    ["queue"],
    multiprocess_mode="max",
)
PAYMENT_EVENTS = Counter(
    "mc_payment_events_total",
    "Payment ledger events by provider and status (pending, processed, ignored, failed).",
    ["provider", "status"],
)
VERIFICATION_OUTCOMES = Counter(
    "mc_verification_outcomes_total",
    "Identity verification attempts reaching an outcome.",
    ["outcome"],
)
OTP_SENDS = Counter(
    "mc_otp_sends_total",
    "OTP SMS sends by number prefix (country code + network prefix only).",
    ["prefix"],
)
REPORTS = Counter(
    "mc_reports_total",
    "Safety reports created by severity.",
    ["severity"],
)
ALERTS = Counter("mc_alerts_total", "Structured alerts emitted.", ["alert"])

_otp_prefixes: set[str] = set()
_otp_lock = threading.Lock()


def method_label(method: str) -> str:
    method = method.upper()
    return method if method in _METHODS else OTHER


def observe_request(*, method: str, route: str | None, status: int, seconds: float) -> None:
    m, r = method_label(method), route or UNMATCHED_ROUTE
    HTTP_REQUESTS.labels(method=m, route=r, status=str(status)).inc()
    HTTP_LATENCY.labels(method=m, route=r).observe(seconds)


def otp_prefix_label(e164: str) -> str:
    """`+256772` for `+256772123456`. Bounded: after MAX_OTP_PREFIXES distinct prefixes, new ones are `other`."""
    prefix = e164[:7]
    with _otp_lock:
        if prefix in _otp_prefixes:
            return prefix
        if len(_otp_prefixes) >= MAX_OTP_PREFIXES:
            return OTHER
        _otp_prefixes.add(prefix)
        return prefix


def count_otp_send(e164: str) -> None:
    OTP_SENDS.labels(prefix=otp_prefix_label(e164)).inc()


def count_payment_event(provider: str, status: str) -> None:
    PAYMENT_EVENTS.labels(provider=provider, status=status).inc()


def count_verification(outcome: str) -> None:
    VERIFICATION_OUTCOMES.labels(outcome=outcome).inc()


def count_report(severity: str) -> None:
    REPORTS.labels(severity=severity).inc()


def count_alert(alert: str) -> None:
    ALERTS.labels(alert=alert).inc()


def render() -> bytes:
    """Text exposition of every metric (aggregated across processes when multiprocess mode is on)."""
    if os.environ.get("PROMETHEUS_MULTIPROC_DIR"):
        registry = CollectorRegistry()
        multiprocess.MultiProcessCollector(registry)
        return generate_latest(registry)
    return generate_latest(REGISTRY)

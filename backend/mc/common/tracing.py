"""OpenTelemetry tracing (Bible §15), strictly opt-in and PII-scrubbed.

* Disabled (a cheap no-op that imports nothing from OpenTelemetry) unless `OTEL_EXPORTER_OTLP_ENDPOINT` is set.
* Sampling: parent-based, `OTEL_TRACES_SAMPLER_RATIO` (default 0.1 = 10%).
* Instrumented: Django, psycopg (no query parameters captured), redis (commands sanitised by the
  instrumentation) and Celery. Health/readiness/metrics probes are excluded.
* Every span passes through `ScrubbingExporter` before it leaves the process: attribute keys that can carry
  personal data are redacted, strings are regex-scrubbed (phones, emails, bearer tokens), URL query strings
  are dropped and redis statements are removed. Span events (exception messages/stack traces) get the same
  treatment. The vendor never sees raw values (CLAUDE.md rule 10).
"""

import logging
import re
from collections.abc import Mapping, Sequence
from typing import Any

from .logging import PII_KEYS, REDACTED, scrub_text

log = logging.getLogger(__name__)

EXCLUDED_URLS = "health,ready,metrics"

# Full attribute names that are always redacted, on top of any whose last dotted segment is in PII_KEYS.
_REDACT_EXACT = frozenset(
    {
        "http.request.header.authorization",
        "http.request.header.cookie",
        "http.response.header.set-cookie",
        "http.request.body",
        "enduser.id",
        "user.email",
        "user.full_name",
        "client.address",
        "http.client_ip",
        "net.peer.ip",
        "net.sock.peer.addr",
    }
)
_URL_KEYS = frozenset({"http.url", "http.target", "url.full"})
_DROP_KEYS = frozenset({"url.query"})
_STATEMENT_KEYS = frozenset({"db.statement", "db.query.text"})
_QUERY_RE = re.compile(r"\?.*$")


def _last_segment(key: str) -> str:
    return re.split(r"[./]", key.lower())[-1]


def scrub_attributes(attributes: Mapping[str, Any] | None) -> dict[str, Any]:
    """Return a scrubbed copy of span/event attributes."""
    out: dict[str, Any] = {}
    attrs = dict(attributes or {})
    is_redis = str(attrs.get("db.system", "")).lower() == "redis"
    for key, value in attrs.items():
        lowered = key.lower()
        if lowered in _DROP_KEYS or (is_redis and lowered in _STATEMENT_KEYS):
            continue
        if (
            lowered in _REDACT_EXACT
            or _last_segment(lowered) in PII_KEYS
            or any(part in lowered for part in ("password", "secret", "authorization", "cookie"))
        ):
            out[key] = REDACTED
        elif isinstance(value, str):
            if lowered in _URL_KEYS:
                value = _QUERY_RE.sub("", value)
            out[key] = scrub_text(value)
        elif isinstance(value, Sequence) and not isinstance(value, bytes | str):
            out[key] = tuple(scrub_text(v) if isinstance(v, str) else v for v in value)
        else:
            out[key] = value
    return out


class ScrubbingExporter:
    """SpanExporter wrapper: scrub every span (attributes and event attributes) before delegating."""

    def __init__(self, delegate: Any) -> None:
        self._delegate = delegate

    def export(self, spans: Sequence[Any]) -> Any:
        return self._delegate.export([scrub_span(s) for s in spans])

    def shutdown(self) -> None:
        self._delegate.shutdown()

    def force_flush(self, timeout_millis: int = 30000) -> bool:
        return bool(self._delegate.force_flush(timeout_millis))


def scrub_span(span: Any) -> Any:
    from opentelemetry.sdk.trace import Event, ReadableSpan

    events = [
        Event(
            name=e.name,
            attributes=scrub_attributes(e.attributes),
            timestamp=e.timestamp,
        )
        for e in span.events
    ]
    status = span.status
    if getattr(status, "description", None):
        from opentelemetry.trace import Status

        status = Status(status.status_code, scrub_text(status.description))
    return ReadableSpan(
        name=scrub_text(span.name),
        context=span.context,
        parent=span.parent,
        resource=span.resource,
        attributes=scrub_attributes(span.attributes),
        events=events,
        links=span.links,
        kind=span.kind,
        status=status,
        start_time=span.start_time,
        end_time=span.end_time,
        instrumentation_scope=span.instrumentation_scope,
    )


_configured = False


def setup_tracing(settings: Any, *, exporter: Any | None = None) -> bool:
    """Configure tracing if (and only if) an OTLP endpoint is set. Idempotent. Returns whether it is on.

    `exporter` lets tests inject an in-memory exporter (it is still wrapped by the scrubber).
    Any failure to start tracing is logged and swallowed: observability must never stop the app.
    """
    global _configured
    endpoint = getattr(settings, "OTEL_EXPORTER_OTLP_ENDPOINT", "")
    if not endpoint and exporter is None:
        return False
    if _configured:
        return True
    try:
        from opentelemetry import trace
        from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
        from opentelemetry.instrumentation.celery import CeleryInstrumentor
        from opentelemetry.instrumentation.django import DjangoInstrumentor
        from opentelemetry.instrumentation.psycopg import PsycopgInstrumentor
        from opentelemetry.instrumentation.redis import RedisInstrumentor
        from opentelemetry.sdk.resources import Resource
        from opentelemetry.sdk.trace import TracerProvider
        from opentelemetry.sdk.trace.export import BatchSpanProcessor, SimpleSpanProcessor
        from opentelemetry.sdk.trace.sampling import ParentBased, TraceIdRatioBased

        ratio = min(1.0, max(0.0, float(getattr(settings, "OTEL_TRACES_SAMPLER_RATIO", 0.1))))
        provider = TracerProvider(
            sampler=ParentBased(TraceIdRatioBased(ratio)),
            resource=Resource.create(
                {"service.name": getattr(settings, "OTEL_SERVICE_NAME", "mc-backend")}
            ),
        )
        scrubbed: Any
        if exporter is not None:
            scrubbed = ScrubbingExporter(exporter)
            provider.add_span_processor(SimpleSpanProcessor(scrubbed))
        else:
            scrubbed = ScrubbingExporter(OTLPSpanExporter(endpoint=_traces_url(endpoint)))
            provider.add_span_processor(BatchSpanProcessor(scrubbed))
        trace.set_tracer_provider(provider)
        DjangoInstrumentor().instrument(tracer_provider=provider, excluded_urls=EXCLUDED_URLS)
        PsycopgInstrumentor().instrument(tracer_provider=provider, capture_parameters=False)
        RedisInstrumentor().instrument(tracer_provider=provider)
        CeleryInstrumentor().instrument(tracer_provider=provider)
    except Exception:
        log.exception("tracing setup failed; continuing without tracing")
        return False
    _configured = True
    return True


def _traces_url(endpoint: str) -> str:
    """OTLP/HTTP wants the full signal path; accept either a base URL or one already ending in /v1/traces."""
    endpoint = endpoint.rstrip("/")
    return endpoint if endpoint.endswith("/v1/traces") else f"{endpoint}/v1/traces"

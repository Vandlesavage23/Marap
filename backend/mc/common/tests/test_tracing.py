import json
import subprocess
import sys
import types

import pytest

from mc.common import tracing

pytest.importorskip("opentelemetry.sdk")


# ---- scrubber -------------------------------------------------------------------------
def test_pii_attribute_keys_are_redacted():
    out = tracing.scrub_attributes(
        {
            "phone": "+256772123456",
            "user.email": "jane@example.com",
            "http.request.header.authorization": "Bearer abc.def",
            "http.request.header.cookie": "mc_admin=xyz",
            "http.request.body": "hello there",
            "messaging.message.body": "I love you",
            "app.token": "tok",
            "exception.message": "failed for +256772123456",
            "db.password": "hunter2",
            "http.status_code": 200,
            "http.method": "GET",
            "http.route": "api/v1/users/<uuid:account_id>",
        }
    )
    assert out["phone"] == out["user.email"] == tracing.REDACTED
    for k in (
        "http.request.header.authorization",
        "http.request.header.cookie",
        "http.request.body",
        "messaging.message.body",
        "app.token",
        "exception.message",
        "db.password",
    ):
        assert out[k] == tracing.REDACTED, k
    assert out["http.status_code"] == 200 and out["http.method"] == "GET"
    assert out["http.route"] == "api/v1/users/<uuid:account_id>"  # non-PII survives


def test_free_text_values_are_regex_scrubbed_and_query_strings_dropped():
    out = tracing.scrub_attributes(
        {
            "http.url": "https://api.mc.test/api/v1/x?phone=%2B256772123456&token=abc",
            "http.target": "/api/v1/x?email=a@b.co",
            "url.query": "phone=1",
            "note": "call +256772123456 or mail jane.doe@example.com with Bearer abc123",
            "db.statement": "SELECT 1 /* jane@example.com */",
            "list": ["+256772123456", "ok", 3],
        }
    )
    blob = json.dumps(out)
    for leak in ("256772123456", "jane", "example.com", "abc123", "token=abc", "phone="):
        assert leak not in blob, leak
    assert out["http.url"] == "https://api.mc.test/api/v1/x"
    assert out["http.target"] == "/api/v1/x"
    assert "url.query" not in out
    assert out["list"][1:] == ("ok", 3)


def test_redis_statements_are_dropped_but_sql_is_kept():
    redis_attrs = tracing.scrub_attributes({"db.system": "redis", "db.statement": "SET ? ?"})
    assert "db.statement" not in redis_attrs and redis_attrs["db.system"] == "redis"
    sql = tracing.scrub_attributes({"db.system": "postgresql", "db.statement": "SELECT 1"})
    assert sql["db.statement"] == "SELECT 1"


def test_scrubber_handles_none_and_non_string_values():
    assert tracing.scrub_attributes(None) == {}
    assert tracing.scrub_attributes({"n": 1, "f": 1.5, "b": True}) == {"n": 1, "f": 1.5, "b": True}


# ---- end to end through a real span, exporter wrapper and sampler -------------------
def test_scrubbing_exporter_scrubs_span_event_and_status_before_delegating():
    from opentelemetry.sdk.trace import TracerProvider
    from opentelemetry.sdk.trace.export import SimpleSpanProcessor
    from opentelemetry.sdk.trace.export.in_memory_span_exporter import InMemorySpanExporter
    from opentelemetry.trace import Status, StatusCode

    memory = InMemorySpanExporter()
    provider = TracerProvider()
    provider.add_span_processor(SimpleSpanProcessor(tracing.ScrubbingExporter(memory)))
    tracer = provider.get_tracer("t")
    with tracer.start_as_current_span("send to +256772123456") as span:
        span.set_attribute("phone", "+256772123456")
        span.set_attribute("http.status_code", 200)
        span.add_event("exception", {"exception.message": "x +256772123456", "exception.type": "E"})
        span.set_status(Status(StatusCode.ERROR, "bad mail jane@example.com"))
    (done,) = memory.get_finished_spans()
    blob = json.dumps(
        [
            done.name,
            dict(done.attributes),
            [dict(e.attributes) for e in done.events],
            done.status.description,
        ]
    )
    assert "256772123456" not in blob and "jane" not in blob
    assert done.attributes["http.status_code"] == 200
    assert done.events[0].attributes["exception.type"] == "E"
    assert done.status.status_code == StatusCode.ERROR


# ---- disabled path ---------------------------------------------------------------------
def test_disabled_without_endpoint_is_a_noop_and_imports_no_otel():
    code = (
        "import sys, types\n"
        "from mc.common import tracing\n"
        "s = types.SimpleNamespace(OTEL_EXPORTER_OTLP_ENDPOINT='')\n"
        "assert tracing.setup_tracing(s) is False\n"
        "assert not [m for m in sys.modules if m.startswith('opentelemetry')], 'otel imported'\n"
    )
    subprocess.run(
        [sys.executable, "-c", code],
        check=True,
        env={"PATH": "", "DJANGO_SETTINGS_MODULE": "config.settings.test"},
    )


def test_disabled_does_not_touch_global_state(monkeypatch):
    monkeypatch.setattr(tracing, "_configured", False)
    s = types.SimpleNamespace(OTEL_EXPORTER_OTLP_ENDPOINT="")
    assert tracing.setup_tracing(s) is False and tracing._configured is False


def test_app_settings_default_to_disabled_with_ten_percent_sampling():
    from django.conf import settings

    assert settings.OTEL_EXPORTER_OTLP_ENDPOINT == ""
    assert settings.OTEL_TRACES_SAMPLER_RATIO == 0.1
    assert tracing._configured is False  # app startup under test settings left tracing off


def test_setup_failure_is_swallowed(monkeypatch, caplog):
    monkeypatch.setattr(tracing, "_configured", False)
    monkeypatch.setattr(
        tracing, "_traces_url", lambda e: (_ for _ in ()).throw(RuntimeError("boom"))
    )
    s = types.SimpleNamespace(OTEL_EXPORTER_OTLP_ENDPOINT="http://collector:4318")
    assert tracing.setup_tracing(s) is False
    assert tracing._configured is False


def test_traces_url_accepts_base_or_full_endpoint():
    assert tracing._traces_url("http://c:4318") == "http://c:4318/v1/traces"
    assert tracing._traces_url("http://c:4318/") == "http://c:4318/v1/traces"
    assert tracing._traces_url("http://c:4318/v1/traces") == "http://c:4318/v1/traces"


# ---- enabled path (subprocess so global instrumentation never leaks into other tests) -----
def test_enabled_path_samples_ten_percent_and_instruments(tmp_path):
    code = r"""
import os, json, types
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.test")
import django; django.setup()
from opentelemetry.sdk.trace.export.in_memory_span_exporter import InMemorySpanExporter
from opentelemetry import trace
from mc.common import tracing
mem = InMemorySpanExporter()
s = types.SimpleNamespace(OTEL_EXPORTER_OTLP_ENDPOINT="", OTEL_TRACES_SAMPLER_RATIO=0.1, OTEL_SERVICE_NAME="t")
assert tracing.setup_tracing(s, exporter=mem) is True
assert tracing.setup_tracing(s, exporter=mem) is True  # idempotent
tracer = trace.get_tracer("x")
n = 4000
for _ in range(n):
    with tracer.start_as_current_span("root"):
        pass
kept = len(mem.get_finished_spans())
assert 0.05 * n < kept < 0.16 * n, kept
from opentelemetry.instrumentation.redis import RedisInstrumentor
from opentelemetry.instrumentation.psycopg import PsycopgInstrumentor
assert RedisInstrumentor().is_instrumented_by_opentelemetry
assert PsycopgInstrumentor().is_instrumented_by_opentelemetry
print("OK", kept)
"""
    import os

    r = subprocess.run(
        [sys.executable, "-c", code],
        capture_output=True,
        text=True,
        env={**os.environ, "DJANGO_SETTINGS_MODULE": "config.settings.test"},
        timeout=60,
    )
    assert r.returncode == 0 and "OK" in r.stdout, r.stdout + r.stderr

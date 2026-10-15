import io
import json
import logging

from mc.common.logging import JsonFormatter, PiiScrubFilter, scrub, sentry_before_send


def _logger():
    stream = io.StringIO()
    handler = logging.StreamHandler(stream)
    handler.setFormatter(JsonFormatter())
    handler.addFilter(PiiScrubFilter())
    log = logging.getLogger("pii-test")
    log.handlers[:] = [handler]
    log.setLevel(logging.INFO)
    log.propagate = False
    return log, stream


def test_phone_and_email_redacted_from_log_output():
    log, stream = _logger()
    log.info("otp sent to +256772123456 and 0772 123 456 for jane.doe@example.com")
    out = stream.getvalue()
    for leaked in ("256772123456", "0772 123 456", "jane.doe", "example.com"):
        assert leaked not in out
    assert json.loads(out)["level"] == "INFO"


def test_pii_keys_and_args_redacted():
    log, stream = _logger()
    log.warning(
        "user %s wrote", "+256772123456", extra={"body": "hi call me", "route": "/x", "phone": "1"}
    )
    data = json.loads(stream.getvalue())
    assert data["body"] == "[redacted]" and data["phone"] == "[redacted]"
    assert data["route"] == "/x"
    assert "256772123456" not in stream.getvalue()


def test_bearer_token_redacted():
    assert "abc.def" not in scrub("Authorization: Bearer abc.def-ghi")


def test_sentry_events_scrubbed():
    event = {
        "message": "failed for +256772123456",
        "request": {
            "data": {"phone": "x"},
            "headers": {"Authorization": "Bearer t"},
            "url": "https://a/b",
        },
        "user": {"email": "a@b.co"},
        "extra": {"description": "free text", "interest_id": "abc"},
        "breadcrumbs": [{"message": "mail to a@b.co"}],
    }
    out = sentry_before_send(event, {})
    text = json.dumps(out)
    assert "256772123456" not in text and "a@b.co" not in text and "free text" not in text
    assert "user" not in out and "data" not in out["request"] and "headers" not in out["request"]
    assert out["extra"]["interest_id"] == "abc"

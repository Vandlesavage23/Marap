"""Structured JSON logging with PII scrubbing (Bible §12.2, §15; CLAUDE.md rule 10).

`scrub()` is shared by the log filter and the Sentry `before_send` hook so the same rules apply to
every sink. Known PII keys are replaced wholesale; free text is regex-redacted for phone numbers,
emails and bearer tokens.
"""

import json
import logging
import re
from typing import Any

from .middleware import request_id_var

REDACTED = "[redacted]"

PII_KEYS = frozenset(
    {
        "phone",
        "phone_e164",
        "email",
        "body",
        "text",
        "description",
        "message",
        "answers",
        "answer",
        "token",
        "access",
        "refresh",
        "refresh_token",
        "access_token",
        "authorization",
        "cookie",
        "password",
        "secret",
        "otp",
        "code",
        "push_token",
        "display_name",
        "id_number",
        "dob",
        "date_of_birth",
        "api_key",
        "signature",
    }
)

_PATTERNS = [
    (re.compile(r"[\w.+-]+@[\w-]+(?:\.[\w-]+)+"), REDACTED),  # email
    (re.compile(r"(?i)bearer\s+[\w\-.~+/]+=*"), "Bearer " + REDACTED),
    (re.compile(r"(?<![\w])\+?\d[\d\s\-().]{7,}\d"), REDACTED),  # phone-like digit runs
]


def scrub_text(value: str) -> str:
    for pattern, repl in _PATTERNS:
        value = pattern.sub(repl, value)
    return value


def scrub(value: Any, _key: str = "") -> Any:
    if _key.lower() in PII_KEYS:
        return REDACTED
    if isinstance(value, dict):
        return {k: scrub(v, str(k)) for k, v in value.items()}
    if isinstance(value, list | tuple):
        return [scrub(v) for v in value]
    if isinstance(value, str):
        return scrub_text(value)
    return value


_STD_ATTRS = set(logging.LogRecord("", 0, "", 0, "", (), None).__dict__) | {"message", "asctime"}


class PiiScrubFilter(logging.Filter):
    def filter(self, record: logging.LogRecord) -> bool:
        record.msg = scrub_text(record.getMessage())
        record.args = ()
        for k in list(record.__dict__):
            if k not in _STD_ATTRS:
                record.__dict__[k] = scrub(record.__dict__[k], k)
        return True


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "ts": self.formatTime(record, "%Y-%m-%dT%H:%M:%S%z"),
            "level": record.levelname,
            "logger": record.name,
            "msg": record.getMessage(),
            "request_id": request_id_var.get(),
        }
        for k, v in record.__dict__.items():
            if k not in _STD_ATTRS:
                payload[k] = v
        if record.exc_info:
            payload["exc"] = scrub_text(self.formatException(record.exc_info))
        return json.dumps(payload, default=str)


def sentry_before_send(event: dict[str, Any], hint: dict[str, Any]) -> dict[str, Any] | None:
    """Scrub PII from Sentry events; also drop request bodies, cookies, headers and user info."""
    request = event.get("request", {})
    for k in ("data", "cookies", "headers", "query_string"):
        request.pop(k, None)
    event.pop("user", None)
    return scrub(event)

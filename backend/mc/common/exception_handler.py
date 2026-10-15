"""Maps every error to RFC 9457 `application/problem+json` with a stable `code`."""

from typing import Any

import redis.exceptions
from django.core.exceptions import PermissionDenied
from django.db import InterfaceError, OperationalError
from django.http import Http404
from rest_framework import exceptions as drf
from rest_framework.response import Response
from rest_framework.views import exception_handler as drf_default_handler

from . import errors

PROBLEM_CONTENT_TYPE = "application/problem+json"
ERROR_TYPE_BASE = "https://docs.marriageconnect.ug/errors/"


def problem_body(
    *, code: str, title: str, status: int, detail: str, **extra: Any
) -> dict[str, Any]:
    return {
        "type": f"{ERROR_TYPE_BASE}{code}",
        "title": title,
        "status": status,
        "code": code,
        "detail": detail,
        **extra,
    }


def _response(body: dict[str, Any], headers: dict[str, str] | None = None) -> Response:
    return Response(body, status=body["status"], headers=headers, content_type=PROBLEM_CONTENT_TYPE)


def _flatten(detail: Any) -> Any:
    if isinstance(detail, dict):
        return {k: _flatten(v) for k, v in detail.items()}
    if isinstance(detail, list):
        return [_flatten(v) for v in detail]
    return str(detail)


def problem_exception_handler(exc: Exception, context: dict[str, Any]) -> Response | None:
    if isinstance(exc, errors.DomainError):
        body = problem_body(
            code=exc.code, title=exc.title, status=exc.status, detail=exc.detail, **exc.extra
        )
        headers = (
            {"Retry-After": str(exc.retry_after)} if isinstance(exc, errors.RateLimited) else None
        )
        return _response(body, headers)
    if isinstance(exc, redis.exceptions.RedisError | OperationalError | InterfaceError):
        # Dependency outage (Redis / Postgres): a clean, retryable 503 — never a stack trace. The transaction that
        # raised it has already rolled back, so nothing is half-written.
        return _response(
            problem_body(
                code="service_unavailable",
                title="Service temporarily unavailable",
                status=503,
                detail="Please try again in a moment.",
            ),
            {"Retry-After": "5"},
        )
    if isinstance(exc, Http404):
        exc = drf.NotFound()
    elif isinstance(exc, PermissionDenied):
        exc = drf.PermissionDenied()

    if isinstance(exc, drf.ValidationError):
        return _response(
            problem_body(
                code="validation_error",
                title="Validation error",
                status=422,
                detail="One or more fields are invalid.",
                errors=_flatten(exc.detail),
            )
        )
    mapping: dict[type[Exception], tuple[str, str]] = {
        drf.NotAuthenticated: ("unauthenticated", "Authentication required"),
        drf.AuthenticationFailed: ("unauthenticated", "Authentication required"),
        drf.PermissionDenied: ("forbidden", "Forbidden"),
        drf.NotFound: ("not_found", "Not found"),
        drf.Throttled: ("rate_limited", "Too many requests"),
        drf.ParseError: ("validation_error", "Malformed request"),
        drf.MethodNotAllowed: ("not_found", "Not found"),
        drf.NotAcceptable: ("validation_error", "Not acceptable"),
        drf.UnsupportedMediaType: ("validation_error", "Unsupported media type"),
    }
    for exc_type, (code, title) in mapping.items():
        if isinstance(exc, exc_type):
            status = {
                "unauthenticated": 401,
                "forbidden": 403,
                "not_found": 404,
                "rate_limited": 429,
            }.get(code, 400 if isinstance(exc, drf.ParseError) else 422)
            if isinstance(exc, drf.MethodNotAllowed):
                status = 405
            retry: dict[str, str] | None = None
            wait = getattr(exc, "wait", None)
            if isinstance(exc, drf.Throttled) and wait:
                retry = {"Retry-After": str(int(wait))}
            return _response(
                problem_body(code=code, title=title, status=status, detail=title + "."), retry
            )
    # Unhandled → let DRF/Django produce a 500; Sentry captures it (no PII in the body).
    return drf_default_handler(exc, context)

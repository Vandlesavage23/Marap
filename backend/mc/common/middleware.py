import contextvars
import logging
import time
import uuid
from collections.abc import Callable

from django.http import HttpRequest, HttpResponse

from . import metrics

request_id_var: contextvars.ContextVar[str] = contextvars.ContextVar("request_id", default="-")

access_log = logging.getLogger("mc.access")
_QUIET_ROUTES = frozenset({"health", "ready", "metrics"})


class RequestIdMiddleware:
    """Attach a request id (inbound X-Request-Id if sane, else generated) for logs and responses."""

    def __init__(self, get_response: Callable[[HttpRequest], HttpResponse]) -> None:
        self.get_response = get_response

    def __call__(self, request: HttpRequest) -> HttpResponse:
        inbound = request.headers.get("X-Request-Id", "")
        rid = (
            inbound
            if 8 <= len(inbound) <= 64 and inbound.isascii() and inbound.isalnum()
            else uuid.uuid4().hex
        )
        token = request_id_var.set(rid)
        try:
            response = self.get_response(request)
        finally:
            request_id_var.reset(token)
        response["X-Request-Id"] = rid
        return response


class SecurityHeadersMiddleware:
    """Strict CSP + framing/caching headers for the server-rendered hosts (admin, pay); the JSON api host gets
    the defaults only."""

    def __init__(self, get_response: Callable[[HttpRequest], HttpResponse]) -> None:
        self.get_response = get_response

    def __call__(self, request: HttpRequest) -> HttpResponse:
        response = self.get_response(request)
        if getattr(request, "urlconf", "config.urls_api") != "config.urls_api":
            response["Content-Security-Policy"] = (
                "default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; frame-ancestors 'none'; base-uri 'none'"
            )
            response["X-Frame-Options"] = "DENY"
            response["Cache-Control"] = "no-store"
        return response


class RequestMetricsMiddleware:
    """Per-route latency/error metrics plus the Bible §15 access log line.

    The label and the logged `route` are the matched URL *pattern* (never the concrete path, query string,
    ids or headers). Probes and `/metrics` are logged at DEBUG so they don't drown real traffic.
    """

    def __init__(self, get_response: Callable[[HttpRequest], HttpResponse]) -> None:
        self.get_response = get_response

    def __call__(self, request: HttpRequest) -> HttpResponse:
        started = time.perf_counter()
        status = 500
        try:
            response = self.get_response(request)
            status = response.status_code
            return response
        finally:
            seconds = time.perf_counter() - started
            match = getattr(request, "resolver_match", None)
            route = (match.route if match is not None else None) or metrics.UNMATCHED_ROUTE
            metrics.observe_request(
                method=request.method or "", route=route, status=status, seconds=seconds
            )
            level = (
                logging.DEBUG if route.strip("/").split("/")[-1] in _QUIET_ROUTES else logging.INFO
            )
            access_log.log(
                level,
                "request",
                extra={
                    "route": route,
                    "method": metrics.method_label(request.method or ""),
                    "status": status,
                    "duration_ms": round(seconds * 1000, 1),
                },
            )

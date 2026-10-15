import contextvars
import uuid
from collections.abc import Callable

from django.http import HttpRequest, HttpResponse

request_id_var: contextvars.ContextVar[str] = contextvars.ContextVar("request_id", default="-")


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

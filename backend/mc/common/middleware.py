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

"""`GET /metrics` (admin host only). Bearer-token protected; fails closed when no token is configured."""

import hmac

from django.conf import settings
from django.http import HttpRequest, HttpResponse, JsonResponse

from . import metrics, queues
from .exception_handler import PROBLEM_CONTENT_TYPE, problem_body


def _problem(
    status: int, code: str, title: str, headers: dict[str, str] | None = None
) -> JsonResponse:
    response = JsonResponse(
        problem_body(code=code, title=title, status=status, detail=title + "."),
        status=status,
        content_type=PROBLEM_CONTENT_TYPE,
    )
    for k, v in (headers or {}).items():
        response[k] = v
    response["Cache-Control"] = "no-store"
    return response


def _bearer(request: HttpRequest) -> str:
    header = request.headers.get("Authorization", "")
    scheme, _, value = header.partition(" ")
    return value.strip() if scheme.lower() == "bearer" else ""


def metrics_view(request: HttpRequest) -> HttpResponse:
    expected: str = settings.METRICS_TOKEN
    if not expected:
        return _problem(403, "forbidden", "Metrics are disabled")
    supplied = _bearer(request)
    if not supplied or not hmac.compare_digest(supplied.encode(), expected.encode()):
        return _problem(
            401, "unauthenticated", "Authentication required", {"WWW-Authenticate": "Bearer"}
        )
    if request.method not in ("GET", "HEAD"):
        return _problem(405, "not_found", "Method not allowed", {"Allow": "GET, HEAD"})
    queues.refresh_gauges()
    response = HttpResponse(
        metrics.render(), content_type="text/plain; version=0.0.4; charset=utf-8"
    )
    response["Cache-Control"] = "no-store"
    return response

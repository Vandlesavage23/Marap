"""Host-based URL routing (Bible §2.2). Unknown host → 400."""

from collections.abc import Callable

from django.conf import settings
from django.core.exceptions import DisallowedHost
from django.http import HttpRequest, HttpResponse, HttpResponseBadRequest

PROBE_PATHS = frozenset({"/ready", "/health"})


class HostRoutingMiddleware:
    def __init__(self, get_response: Callable[[HttpRequest], HttpResponse]) -> None:
        self.get_response = get_response

    def __call__(self, request: HttpRequest) -> HttpResponse:
        if request.path in PROBE_PATHS:
            # Load-balancer probes carry the target IP as Host; pin them to the api host (probe paths only).
            api_host = next(h for h, u in settings.HOST_URLCONFS.items() if u == "config.urls_api")
            request.META["HTTP_HOST"] = api_host
        try:
            host = request.get_host().split(":")[0].lower()
        except DisallowedHost:
            return HttpResponseBadRequest("Unknown host")
        urlconf = settings.HOST_URLCONFS.get(host)
        if urlconf is None:
            return HttpResponseBadRequest("Unknown host")
        request.urlconf = urlconf
        return self.get_response(request)


class WebSocketHostMiddleware:
    """ASGI middleware: WebSocket connections are only accepted on the api host."""

    def __init__(self, app):  # type: ignore[no-untyped-def]
        self.app = app

    async def __call__(self, scope, receive, send):  # type: ignore[no-untyped-def]
        host = ""
        for name, value in scope.get("headers", []):
            if name == b"host":
                host = value.decode().split(":")[0].lower()
        if settings.HOST_URLCONFS.get(host) != "config.urls_api":
            await send({"type": "websocket.close", "code": 4400})
            return
        return await self.app(scope, receive, send)

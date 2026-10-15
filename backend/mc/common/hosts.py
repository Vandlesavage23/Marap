"""Host-based URL routing (Bible §2.2). Unknown host → 400."""

from collections.abc import Callable

from django.conf import settings
from django.core.exceptions import DisallowedHost
from django.http import HttpRequest, HttpResponse, HttpResponseBadRequest


class HostRoutingMiddleware:
    def __init__(self, get_response: Callable[[HttpRequest], HttpResponse]) -> None:
        self.get_response = get_response

    def __call__(self, request: HttpRequest) -> HttpResponse:
        try:
            host = request.get_host().split(":")[0].lower()
        except DisallowedHost:
            return HttpResponseBadRequest("Unknown host")
        urlconf = settings.HOST_URLCONFS.get(host)
        if urlconf is None:
            return HttpResponseBadRequest("Unknown host")
        request.urlconf = urlconf
        return self.get_response(request)

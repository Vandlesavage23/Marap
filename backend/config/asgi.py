import os

from django.core.asgi import get_asgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.local")
django_asgi_app = get_asgi_application()

from channels.routing import ProtocolTypeRouter, URLRouter  # noqa: E402
from django.urls import path  # noqa: E402

from mc.common.hosts import WebSocketHostMiddleware  # noqa: E402
from mc.messaging.consumers import ChatConsumer  # noqa: E402

websocket_urlpatterns = [path("ws/chat", ChatConsumer.as_asgi())]

application = ProtocolTypeRouter(
    {
        "http": django_asgi_app,
        # Auth is the first-frame token (no cookies), so there is no CSRF-for-WebSocket surface; the host
        # allowlist still applies.
        "websocket": WebSocketHostMiddleware(URLRouter(websocket_urlpatterns)),
    }
)

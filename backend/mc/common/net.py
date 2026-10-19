from django.conf import settings
from django.http import HttpRequest


def client_ip(request: HttpRequest) -> str:
    """Client IP honouring exactly `MC_TRUSTED_PROXY_COUNT` proxies (never trust the whole header)."""
    proxies = settings.MC_TRUSTED_PROXY_COUNT
    forwarded = request.META.get("HTTP_X_FORWARDED_FOR", "")
    if proxies and forwarded:
        parts = [p.strip() for p in forwarded.split(",") if p.strip()]
        if len(parts) >= proxies:
            return parts[-proxies]
    return str(request.META.get("REMOTE_ADDR", "0.0.0.0"))  # noqa: S104


def request_install_id(request: HttpRequest) -> str | None:
    """The calling device's install id (from the live session's device), or None for sessions without a device."""
    session = getattr(request, "session_obj", None)
    device = getattr(session, "device", None)
    install_id = getattr(device, "install_id", None)
    return str(install_id) if install_id else None

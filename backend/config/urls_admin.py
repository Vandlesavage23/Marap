# Staff portal routes (MC-113). The Django default admin is deliberately not installed.
from django.urls import path

from mc.adminportal.urls import urlpatterns as _portal_urlpatterns
from mc.common.metrics_view import metrics_view

# `/metrics` lives on the admin host only (never the public api host) and is bearer-token protected.
urlpatterns = [*_portal_urlpatterns, path("metrics", metrics_view, name="metrics")]

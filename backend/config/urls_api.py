from django.conf import settings
from django.urls import include, path

from mc.common.api import urls as common_urls

urlpatterns = [
    path("api/v1/", include((common_urls.urlpatterns, "common"))),
    path("api/v1/", include("mc.accounts.api.urls")),
    path("api/v1/", include("mc.verification.api.urls")),
    path("api/v1/", include("mc.entitlements.api.urls")),
    # Unversioned probes for load balancers.
    path("", include((common_urls.probe_urlpatterns, "probes"))),
]

if settings.OPENAPI_ENABLED:
    from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView

    urlpatterns += [
        path("api/v1/schema/", SpectacularAPIView.as_view(), name="schema"),
        path("api/v1/docs/", SpectacularSwaggerView.as_view(url_name="schema")),
    ]

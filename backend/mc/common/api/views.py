from django.db import connection
from drf_spectacular.utils import extend_schema
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from mc.common.exception_handler import problem_body
from mc.common.redis import get_redis


class HealthView(APIView):
    permission_classes = [AllowAny]

    @extend_schema(responses={200: dict}, auth=[])
    def get(self, request):  # type: ignore[no-untyped-def]
        return Response({"status": "ok"})


class ReadyView(APIView):
    """Checks DB + Redis. Returns no data beyond pass/fail (Bible §8.2)."""

    permission_classes = [AllowAny]

    @extend_schema(responses={200: dict, 503: dict}, auth=[])
    def get(self, request):  # type: ignore[no-untyped-def]
        try:
            with connection.cursor() as cur:
                cur.execute("SELECT 1")
            get_redis().ping()
        except Exception:
            return Response(
                problem_body(
                    code="provider_error",
                    title="Not ready",
                    status=503,
                    detail="A dependency is unavailable.",
                ),
                status=503,
            )
        return Response({"status": "ready"})

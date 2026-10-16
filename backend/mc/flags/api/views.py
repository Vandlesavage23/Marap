from drf_spectacular.utils import extend_schema
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from mc.flags import selectors


class FlagsView(APIView):
    """Public, non-sensitive flags only (a fixed allowlist: never phase 5 or ranking keys)."""

    permission_classes = [AllowAny]
    authentication_classes: list = []

    @extend_schema(responses={200: dict}, auth=[])
    def get(self, request):  # type: ignore[no-untyped-def]
        resp = Response({"flags": selectors.public_flags()})
        resp["Cache-Control"] = "public, max-age=60"
        return resp

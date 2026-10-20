from drf_spectacular.utils import extend_schema
from rest_framework import status
from rest_framework.exceptions import ValidationError
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from mc.accounts.permissions import IsActiveMember
from mc.common.net import client_ip, request_install_id
from mc.common.pagination import parse_limit
from mc.common.serializers import reject_unknown_fields
from mc.discovery import services

from . import serializers as s


class DiscoveryView(APIView):
    permission_classes = [IsActiveMember]

    @extend_schema(responses={200: dict})
    def get(self, request):  # type: ignore[no-untyped-def]
        page = services.next_candidates(
            request.user,
            cursor=request.query_params.get("cursor") or None,
            limit=parse_limit(request.query_params.get("limit")),
            ip=client_ip(request),
            install_id=request_install_id(request),
        )
        return Response(page)


class FeedbackView(APIView):
    permission_classes = [IsActiveMember]

    @extend_schema(request=s.FeedbackSerializer, responses={204: None})
    def post(self, request):  # type: ignore[no-untyped-def]
        data = s.FeedbackSerializer(data=request.data)
        reject_unknown_fields(data, request.data)
        data.is_valid(raise_exception=True)
        services.record_feedback(
            viewer=request.user,
            profile_id=data.validated_data["profile_id"],
            action=data.validated_data["action"],
        )
        return Response(status=status.HTTP_204_NO_CONTENT)


class GuestDiscoveryView(APIView):
    """Signed-out browsing: GET /discovery/guest?seeking=female|male&cursor= (no account, limited cards)."""

    permission_classes = [AllowAny]
    authentication_classes: list = []

    @extend_schema(responses={200: dict})
    def get(self, request):  # type: ignore[no-untyped-def]
        seeking = request.query_params.get("seeking")
        if seeking not in ("male", "female"):
            raise ValidationError({"seeking": "Use male or female."})
        return Response(
            services.guest_feed(
                seeking=seeking,
                cursor=request.query_params.get("cursor") or None,
                limit=parse_limit(request.query_params.get("limit")) or 10,
                ip=client_ip(request),
                install_id=request_install_id(request),
            )
        )

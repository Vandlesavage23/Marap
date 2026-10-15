from drf_spectacular.utils import extend_schema
from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from mc.accounts.permissions import IsActiveMember
from mc.common.idempotency import IdempotentMixin
from mc.common.serializers import reject_unknown_fields
from mc.verification import review, selectors, services

from . import serializers as s


class CreateSessionView(IdempotentMixin):
    permission_classes = [IsActiveMember]

    @extend_schema(request=s.CreateSessionSerializer, responses={201: dict})
    def perform_idempotent(self, request):  # type: ignore[no-untyped-def]
        data = s.CreateSessionSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        attempt, params = services.create_session(
            account=request.user,
            id_type=data.validated_data["id_type"],
            issuing_country=data.validated_data["issuing_country"].upper(),
        )
        return status.HTTP_201_CREATED, {"attempt_id": str(attempt.id), "sdk_params": params}


class SubmittedView(APIView):
    permission_classes = [IsActiveMember]

    @extend_schema(request=None, responses={200: dict})
    def post(self, request, attempt_id):  # type: ignore[no-untyped-def]
        att = services.mark_submitted(account=request.user, attempt_id=attempt_id)
        return Response({"attempt_id": str(att.id), "status": att.status})


class StatusView(APIView):
    permission_classes = [IsActiveMember]

    @extend_schema(responses={200: dict})
    def get(self, request):  # type: ignore[no-untyped-def]
        return Response(selectors.latest_status(request.user))


class SmileIdWebhookView(APIView):
    permission_classes = [AllowAny]
    authentication_classes: list = []

    @extend_schema(request=None, responses={200: dict}, auth=[])
    def post(self, request):  # type: ignore[no-untyped-def]
        body = request._request.body  # raw bytes: the signature covers them exactly
        services.handle_vendor_callback(body=body, headers=request.headers)
        return Response({"status": "ok"})


class AppealView(IdempotentMixin):
    permission_classes = [IsActiveMember]

    @extend_schema(request=s.AppealSerializer, responses={201: dict})
    def perform_idempotent(self, request):  # type: ignore[no-untyped-def]
        data = s.AppealSerializer(data=request.data)
        reject_unknown_fields(data, request.data)
        data.is_valid(raise_exception=True)
        appeal = review.open_appeal(
            account=request.user,
            attempt_id=data.validated_data.get("attempt_id"),
            message=data.validated_data["message"],
        )
        return status.HTTP_201_CREATED, {"id": str(appeal.id), "status": appeal.status}

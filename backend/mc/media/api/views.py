import json

from drf_spectacular.utils import extend_schema
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.utils.encoders import JSONEncoder
from rest_framework.views import APIView

from mc.common.errors import NotFound
from mc.common.idempotency import IdempotentMixin
from mc.common.serializers import reject_unknown_fields
from mc.media import selectors, services
from mc.media.policies import can_view_media

from . import serializers as s


def media_payload(media, viewer=None) -> dict:  # type: ignore[no-untyped-def]
    body = {
        "id": str(media.id),
        "purpose": media.purpose,
        "status": media.status,
        "reject_reason": media.reject_reason or None,
        "width": media.width,
        "height": media.height,
        "duration_ms": media.duration_ms,
    }
    if viewer is not None and media.status == "ready":
        url = selectors.signed_url(media, viewer)
        if url:
            body["url"] = url
    return body


class UploadsView(IdempotentMixin):
    permission_classes = [IsAuthenticated]

    @extend_schema(request=s.UploadRequestSerializer, responses={201: dict})
    def perform_idempotent(self, request):  # type: ignore[no-untyped-def]
        data = s.UploadRequestSerializer(data=request.data)
        reject_unknown_fields(data, request.data)
        data.is_valid(raise_exception=True)
        v = data.validated_data
        media, post = services.create_upload(
            owner=request.user,
            purpose=v["purpose"],
            mime=v["mime"],
            size=v["bytes"],
            sha256=v["sha256"],
        )
        body = {
            "id": str(media.id),
            "upload": {"url": post.url, "fields": post.fields, "method": "POST"},
            "expires_in": 300,
        }
        return status.HTTP_201_CREATED, json.loads(json.dumps(body, cls=JSONEncoder))


class CompleteView(APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(request=None, responses={202: dict})
    def post(self, request, media_id):  # type: ignore[no-untyped-def]
        media = services.complete_upload(owner=request.user, media_id=media_id)
        return Response(media_payload(media), status=status.HTTP_202_ACCEPTED)


class MediaDetailView(APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(responses={200: dict})
    def get(self, request, media_id):  # type: ignore[no-untyped-def]
        media = selectors.get_media(media_id)
        if media is None or not can_view_media(request.user, media):
            raise NotFound()
        return Response(media_payload(media, request.user))

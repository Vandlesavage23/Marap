import json

from drf_spectacular.utils import extend_schema, extend_schema_serializer
from rest_framework import serializers, status
from rest_framework.response import Response
from rest_framework.utils.encoders import JSONEncoder
from rest_framework.views import APIView

from mc.accounts.permissions import IsAuthenticatedAnyStatus
from mc.common.pagination import parse_limit
from mc.common.serializers import reject_unknown_fields
from mc.notifications import selectors, services


@extend_schema_serializer(component_name="NotificationsRead")
class ReadSerializer(serializers.Serializer):
    ids = serializers.ListField(child=serializers.UUIDField(), required=False, allow_null=True)


class InboxView(APIView):
    permission_classes = [IsAuthenticatedAnyStatus]

    @extend_schema(responses={200: dict})
    def get(self, request):  # type: ignore[no-untyped-def]
        page = selectors.inbox(
            request.user.id,
            cursor=request.query_params.get("cursor"),
            limit=parse_limit(request.query_params.get("limit")),
        )
        body = page.as_dict(
            lambda n: {
                "id": str(n.id),
                "type": n.type,
                "payload": n.payload,
                "read": n.read_at is not None,
                "created_at": n.created_at,
            }
        )
        body["unread"] = selectors.unread_count(request.user.id)
        return Response(json.loads(json.dumps(body, cls=JSONEncoder)))


class MarkReadView(APIView):
    permission_classes = [IsAuthenticatedAnyStatus]

    @extend_schema(request=ReadSerializer, responses={204: None})
    def post(self, request):  # type: ignore[no-untyped-def]
        data = ReadSerializer(data=request.data)
        reject_unknown_fields(data, request.data)
        data.is_valid(raise_exception=True)
        services.mark_read(account_id=request.user.id, ids=data.validated_data.get("ids"))
        return Response(status=status.HTTP_204_NO_CONTENT)

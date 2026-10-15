import json

from drf_spectacular.utils import extend_schema
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.utils.encoders import JSONEncoder
from rest_framework.views import APIView

from mc.common.serializers import reject_unknown_fields
from mc.profiles import selectors as profile_selectors
from mc.safety import selectors, services

from . import serializers as s


class BlocksView(APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(request=s.BlockSerializer, responses={201: dict})
    def post(self, request):  # type: ignore[no-untyped-def]
        data = s.BlockSerializer(data=request.data)
        reject_unknown_fields(data, request.data)
        data.is_valid(raise_exception=True)
        services.block_by_profile(
            blocker=request.user, profile_id=data.validated_data["profile_id"]
        )
        return Response({"blocked": True}, status=status.HTTP_201_CREATED)

    @extend_schema(responses={200: dict})
    def get(self, request):  # type: ignore[no-untyped-def]
        rows = list(selectors.blocked_members(request.user.id)[:200])
        summaries = profile_selectors.member_summaries([b.blocked_id for b in rows], request.user)
        items = [
            {
                "profile_id": summaries[b.blocked_id]["id"],
                "display_name": summaries[b.blocked_id]["display_name"],
                "blocked_at": b.created_at,
            }
            for b in rows
            if b.blocked_id in summaries
        ]
        return Response(
            json.loads(json.dumps({"items": items, "next_cursor": None}, cls=JSONEncoder))
        )


class UnblockView(APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(responses={204: None})
    def delete(self, request, profile_id):  # type: ignore[no-untyped-def]
        services.unblock(blocker=request.user, profile_id=profile_id)
        return Response(status=status.HTTP_204_NO_CONTENT)

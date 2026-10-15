import json

from drf_spectacular.utils import extend_schema
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.utils.encoders import JSONEncoder
from rest_framework.views import APIView

from mc.common.errors import EntitlementRequired, NotFound
from mc.common.pagination import parse_limit
from mc.common.serializers import reject_unknown_fields
from mc.matches import selectors as match_selectors
from mc.messaging import policies, selectors, services

from . import serializers as s


def _plain(body: object) -> object:
    return json.loads(json.dumps(body, cls=JSONEncoder))


def _readable_match(request, match_id):  # type: ignore[no-untyped-def]
    match = match_selectors.get_match(match_id)
    if (
        match is None
        or not match_selectors.is_match_member(match, request.user.id)
        or match.status != "active"
    ):
        raise NotFound()
    if not policies.can_read_conversation(request.user, match):
        from mc.entitlements import selectors as ent

        if not ent.has_capability(request.user, "read_conversations"):
            raise EntitlementRequired(
                "Verify your identity to read messages.", capability="read_conversations"
            )
        raise NotFound()
    return match


class MessagesView(APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(responses={200: dict})
    def get(self, request, match_id):  # type: ignore[no-untyped-def]
        match = _readable_match(request, match_id)
        page = selectors.history(
            match,
            before=request.query_params.get("before"),
            limit=parse_limit(request.query_params.get("limit")),
        )
        return Response(_plain(page.as_dict(lambda m: selectors.message_payload(m, request.user))))

    @extend_schema(request=s.SendMessageSerializer, responses={201: dict, 200: dict})
    def post(self, request, match_id):  # type: ignore[no-untyped-def]
        """REST fallback for the outbox when the socket is down; same semantics as the `msg.send` frame."""
        data = s.SendMessageSerializer(data=request.data)
        reject_unknown_fields(data, request.data)
        data.is_valid(raise_exception=True)
        v = data.validated_data
        msg, created = services.send_message(
            sender=request.user,
            match_id=match_id,
            client_msg_id=v["client_msg_id"],
            kind=v["kind"],
            body=v.get("body"),
            media_id=v.get("media_id"),
        )
        return Response(
            _plain(selectors.message_payload(msg, request.user)),
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )


class ReadView(APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(request=s.ReadSerializer, responses={204: None})
    def post(self, request, match_id):  # type: ignore[no-untyped-def]
        data = s.ReadSerializer(data=request.data)
        reject_unknown_fields(data, request.data)
        data.is_valid(raise_exception=True)
        services.mark_read(
            account=request.user,
            match_id=match_id,
            up_to_message_id=data.validated_data["up_to_message_id"],
        )
        return Response(status=status.HTTP_204_NO_CONTENT)

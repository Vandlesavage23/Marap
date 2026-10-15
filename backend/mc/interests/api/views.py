import json

from drf_spectacular.utils import extend_schema
from rest_framework import status
from rest_framework.response import Response
from rest_framework.utils.encoders import JSONEncoder
from rest_framework.views import APIView

from mc.accounts.permissions import IsActiveMember
from mc.common.errors import EntitlementRequired, NotFound
from mc.common.idempotency import IdempotentMixin, validate_key
from mc.common.pagination import parse_limit
from mc.common.serializers import reject_unknown_fields
from mc.entitlements import selectors as entitlement_selectors
from mc.interests import selectors, services
from mc.profiles import selectors as profile_selectors

from . import serializers as s


def _plain(body: dict) -> dict:
    return json.loads(json.dumps(body, cls=JSONEncoder))


class SendInterestView(IdempotentMixin):
    permission_classes = [IsActiveMember]

    @extend_schema(request=s.SendInterestSerializer, responses={201: dict, 200: dict})
    def perform_idempotent(self, request):  # type: ignore[no-untyped-def]
        data = s.SendInterestSerializer(data=request.data)
        reject_unknown_fields(data, request.data)
        data.is_valid(raise_exception=True)
        key = validate_key(request.headers.get("Idempotency-Key"))
        result = services.send_interest(
            sender=request.user,
            recipient_profile_id=data.validated_data["recipient_id"],
            idempotency_key=key or "",
        )
        interest = result["interest"]
        if result["match_id"]:
            return status.HTTP_200_OK, _plain(
                {
                    "id": str(interest.id),
                    "recipient_id": str(data.validated_data["recipient_id"]),
                    "status": "accepted",
                    "match_id": str(result["match_id"]),
                }
            )
        return (status.HTTP_201_CREATED if result["created"] else status.HTTP_200_OK), _plain(
            {
                "id": str(interest.id),
                "recipient_id": str(data.validated_data["recipient_id"]),
                "status": selectors.sender_visible_status(interest),
                "expires_at": interest.expires_at,
                "created_at": interest.created_at,
                "remaining_today": result["remaining_today"],
            }
        )


def _received_item(i, summaries) -> dict:  # type: ignore[no-untyped-def]
    return {
        "id": str(i.id),
        "sender": summaries.get(i.sender_id),
        "snapshot": {"text": i.snapshot.text, "created_at": i.snapshot.created_at}
        if i.snapshot
        else None,
        "status": i.status,
        "created_at": i.created_at,
        "expires_at": i.expires_at,
    }


class ReceivedView(APIView):
    permission_classes = [IsActiveMember]

    @extend_schema(responses={200: dict})
    def get(self, request):  # type: ignore[no-untyped-def]
        if not entitlement_selectors.has_capability(request.user, "receive_interest"):
            raise EntitlementRequired(
                "Verify your identity to see who's interested.", capability="receive_interest"
            )
        page = selectors.received(
            request.user.id,
            cursor=request.query_params.get("cursor"),
            limit=parse_limit(request.query_params.get("limit")),
        )
        summaries = profile_selectors.member_summaries(
            [i.sender_id for i in page.items], request.user
        )
        return Response(_plain(page.as_dict(lambda i: _received_item(i, summaries))))


class SentView(APIView):
    permission_classes = [IsActiveMember]

    @extend_schema(responses={200: dict})
    def get(self, request):  # type: ignore[no-untyped-def]
        page = selectors.sent(
            request.user.id,
            cursor=request.query_params.get("cursor"),
            limit=parse_limit(request.query_params.get("limit")),
        )
        summaries = profile_selectors.member_summaries(
            [i.recipient_id for i in page.items], request.user
        )

        def item(i):  # type: ignore[no-untyped-def]
            return {
                "id": str(i.id),
                "recipient": summaries.get(i.recipient_id),
                "status": selectors.sender_visible_status(i),
                "created_at": i.created_at,
                "expires_at": i.expires_at,
            }

        return Response(_plain(page.as_dict(item)))


class AcceptView(IdempotentMixin):
    permission_classes = [IsActiveMember]

    @extend_schema(request=None, responses={200: dict})
    def perform_idempotent(self, request, interest_id=None):  # type: ignore[no-untyped-def]
        interest, match_id = services.accept_interest(
            recipient=request.user, interest_id=self.kwargs["interest_id"]
        )
        return status.HTTP_200_OK, {
            "id": str(interest.id),
            "status": "accepted",
            "match_id": str(match_id),
        }


class PassView(APIView):
    permission_classes = [IsActiveMember]

    @extend_schema(request=None, responses={204: None})
    def post(self, request, interest_id):  # type: ignore[no-untyped-def]
        if selectors.get_for_recipient(interest_id, request.user.id) is None:
            raise NotFound()
        services.pass_interest(recipient=request.user, interest_id=interest_id)
        return Response(status=status.HTTP_204_NO_CONTENT)

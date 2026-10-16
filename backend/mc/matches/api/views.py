import json

from drf_spectacular.utils import extend_schema
from rest_framework import status
from rest_framework.response import Response
from rest_framework.utils.encoders import JSONEncoder
from rest_framework.views import APIView

from mc.accounts.permissions import IsActiveMember
from mc.common.errors import EntitlementRequired, NotFound
from mc.common.pagination import paginate, parse_limit
from mc.entitlements import selectors as entitlement_selectors
from mc.matches import selectors, services
from mc.matches.models import Match
from mc.messaging import selectors as messaging_selectors
from mc.profiles import selectors as profile_selectors
from mc.safety import selectors as safety_selectors


class MatchesView(APIView):
    permission_classes = [IsActiveMember]

    @extend_schema(responses={200: dict})
    def get(self, request):  # type: ignore[no-untyped-def]
        if not entitlement_selectors.has_capability(request.user, "read_conversations"):
            raise EntitlementRequired(
                "Verify your identity to see your matches.", capability="read_conversations"
            )
        blocked = safety_selectors.blocked_either_way_ids(request.user.id)
        qs = (
            selectors.active_matches(request.user.id)
            .exclude(user_a_id__in=blocked)
            .exclude(user_b_id__in=blocked)
        )
        page = paginate(
            qs,
            cursor=request.query_params.get("cursor"),
            limit=parse_limit(request.query_params.get("limit")),
        )
        others = {m.id: selectors.other_member(m, request.user.id) for m in page.items}
        summaries = profile_selectors.member_summaries(others.values(), request.user)
        chats = messaging_selectors.conversation_summaries(
            [m.id for m in page.items], request.user.id
        )

        def item(m: Match) -> dict:
            chat = chats.get(m.id, messaging_selectors.EMPTY_SUMMARY)
            return {
                "id": str(m.id),
                "member": summaries.get(others[m.id]),
                "created_at": m.created_at,
                # chat activity for the list screen; never the message text
                "last_message_at": chat.last_message_at,
                "last_message_kind": chat.last_message_kind,
                "last_message_sender": chat.last_message_sender,
                "unread_count": chat.unread_count,
            }

        return Response(json.loads(json.dumps(page.as_dict(item), cls=JSONEncoder)))


class UnmatchView(APIView):
    permission_classes = [IsActiveMember]

    @extend_schema(request=None, responses={204: None})
    def post(self, request, match_id):  # type: ignore[no-untyped-def]
        match = selectors.get_match(match_id)
        if match is None or not selectors.is_match_member(match, request.user.id):
            raise NotFound()
        services.unmatch(match_id=match_id, by=request.user.id)
        return Response(status=status.HTTP_204_NO_CONTENT)

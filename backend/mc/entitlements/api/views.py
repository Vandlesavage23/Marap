import json

from django.utils import timezone
from drf_spectacular.utils import extend_schema
from rest_framework import status
from rest_framework.response import Response
from rest_framework.utils.encoders import JSONEncoder
from rest_framework.views import APIView

from mc.accounts.permissions import IsActiveMember
from mc.common import quota
from mc.common.idempotency import IdempotentMixin
from mc.common.timeutil import next_kampala_midnight
from mc.entitlements import selectors, services
from mc.interests import selectors as interest_selectors
from mc.verification import selectors as verification_selectors


def entitlements_payload(account) -> dict:  # type: ignore[no-untyped-def]
    """Everything the app needs to render quotas, the membership offer and the verification prompt, so it never
    guesses: capabilities, the interest allowance, today's card allowance, trial availability, verification."""
    now = timezone.now()
    s = selectors.entitlement_summary(account, now)
    interests = interest_selectors.allowance(account.id, state=s.state, now=now)
    card_limit = selectors.browse_card_limit(s)
    open_limit = selectors.profile_open_limit(s)
    return {
        "state": s.state,
        "trial": {
            "used": s.trial_used,
            "available": s.trial_available,
            "started_at": s.trial_started_at,
            "ends_at": s.trial_ends_at,
        },
        "membership": (
            {"ends_at": s.membership_ends_at, "source": s.membership_source}
            if s.membership_ends_at
            else None
        ),
        "capabilities": s.capabilities,
        "interests": {
            "limit": interests.limit,
            "used": interests.used,
            "resets_at": interests.resets_at,
            "period": interests.period,
        },
        "browse": {
            "limit": card_limit,
            "used": quota.used(quota.day_key("cards", account.id, now)),
            "resets_at": next_kampala_midnight(now),
        },
        "profile_opens": {
            "limit": open_limit,
            "used": quota.used_unique(quota.day_key("open", account.id, now)),
            "resets_at": next_kampala_midnight(now),
        },
        "verification": {
            "status": verification_selectors.latest_status(account)["status"],
            "verified": s.verified,
        },
        "server_time": now,
    }


class EntitlementsView(APIView):
    permission_classes = [IsActiveMember]

    @extend_schema(responses={200: dict})
    def get(self, request):  # type: ignore[no-untyped-def]
        return Response(entitlements_payload(request.user))


class StartTrialView(IdempotentMixin):
    permission_classes = [IsActiveMember]

    @extend_schema(request=None, responses={201: dict})
    def perform_idempotent(self, request):  # type: ignore[no-untyped-def]
        services.start_trial(account=request.user)
        return status.HTTP_201_CREATED, json.loads(
            json.dumps(entitlements_payload(request.user), cls=JSONEncoder)
        )

import json

from django.utils import timezone
from drf_spectacular.utils import extend_schema
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.utils.encoders import JSONEncoder
from rest_framework.views import APIView

from mc.common.idempotency import IdempotentMixin
from mc.entitlements import selectors, services


def entitlements_payload(account) -> dict:  # type: ignore[no-untyped-def]
    now = timezone.now()
    s = selectors.entitlement_summary(account, now)
    return {
        "state": s.state,
        "trial": {"used": s.trial_used, "ends_at": s.trial_ends_at},
        "membership": (
            {"ends_at": s.membership_ends_at, "source": s.membership_source}
            if s.membership_ends_at
            else None
        ),
        "capabilities": s.capabilities,
        "server_time": now,
    }


class EntitlementsView(APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(responses={200: dict})
    def get(self, request):  # type: ignore[no-untyped-def]
        return Response(entitlements_payload(request.user))


class StartTrialView(IdempotentMixin):
    permission_classes = [IsAuthenticated]

    @extend_schema(request=None, responses={201: dict})
    def perform_idempotent(self, request):  # type: ignore[no-untyped-def]
        services.start_trial(account=request.user)
        return status.HTTP_201_CREATED, json.loads(
            json.dumps(entitlements_payload(request.user), cls=JSONEncoder)
        )

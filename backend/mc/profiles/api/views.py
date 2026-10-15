from drf_spectacular.utils import extend_schema
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from mc.common.errors import NotFound
from mc.common.serializers import reject_unknown_fields
from mc.profiles import policies, services
from mc.profiles.models import Profile

from . import serializers as s


class MyProfileView(APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(responses={200: dict})
    def get(self, request):  # type: ignore[no-untyped-def]
        return Response(s.own_profile(services.get_or_create_profile(account=request.user)))

    @extend_schema(request=s.ProfileUpdateSerializer, responses={200: dict})
    def patch(self, request):  # type: ignore[no-untyped-def]
        data = s.ProfileUpdateSerializer(data=request.data, partial=True)
        reject_unknown_fields(data, request.data)
        data.is_valid(raise_exception=True)
        profile = services.update_profile(account=request.user, data=dict(data.validated_data))
        return Response(s.own_profile(profile))


class PublicProfileView(APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(responses={200: dict})
    def get(self, request, profile_id):  # type: ignore[no-untyped-def]
        target = Profile.objects.select_related("account").filter(id=profile_id).first()
        # Same 404 whether it doesn't exist or you may not see it (no existence oracle).
        if target is None or not policies.can_view_profile(request.user, target):
            raise NotFound()
        return Response(s.public_profile(target))

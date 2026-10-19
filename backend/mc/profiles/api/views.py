import json

from drf_spectacular.utils import extend_schema
from rest_framework import serializers, status
from rest_framework.response import Response
from rest_framework.utils.encoders import JSONEncoder
from rest_framework.views import APIView

from mc.accounts.permissions import IsActiveMember
from mc.common.errors import NotFound
from mc.common.idempotency import IdempotentMixin
from mc.common.net import client_ip, request_install_id
from mc.common.serializers import reject_unknown_fields
from mc.profiles import photos, policies, preferences, services
from mc.profiles.models import Profile

from . import serializers as s


class ProfilePatchBody(s.ProfileUpdateSerializer):
    """PATCH body. `birth_date` ("About you") is accepted only until the identity check passes; from then on the
    ID's date of birth is the only truth. It is declared here, in the request-only serializer, and not in
    `serializers.py` where `test_serializers_never_expose_identity_fields` guards the output allowlists."""

    birth_date = serializers.DateField(required=False)


class MyProfileView(APIView):
    permission_classes = [IsActiveMember]

    @extend_schema(responses={200: dict})
    def get(self, request):  # type: ignore[no-untyped-def]
        # An unverified member who finished "About you" can read their draft (readiness lists `verification`).
        return Response(
            s.own_profile(
                services.get_or_create_profile(account=request.user, allow_unverified=True)
            )
        )

    @extend_schema(request=ProfilePatchBody, responses={200: dict})
    def patch(self, request):  # type: ignore[no-untyped-def]
        data = ProfilePatchBody(data=request.data, partial=True)
        reject_unknown_fields(data, request.data)
        data.is_valid(raise_exception=True)
        profile = services.update_profile(account=request.user, data=dict(data.validated_data))
        return Response(s.own_profile(profile))


class PublicProfileView(APIView):
    permission_classes = [IsActiveMember]

    @extend_schema(responses={200: dict})
    def get(self, request, profile_id):  # type: ignore[no-untyped-def]
        target = Profile.objects.select_related("account").filter(id=profile_id).first()
        # Same 404 whether it doesn't exist or you may not see it (no existence oracle).
        if target is None or not policies.can_view_profile(request.user, target):
            raise NotFound()
        locked = services.open_profile(
            viewer=request.user,
            target=target,
            ip=client_ip(request),
            install_id=request_install_id(request),
        )
        return Response(s.public_profile(target, request.user, locked=locked))


class DescriptionsView(IdempotentMixin):
    permission_classes = [IsActiveMember]

    @extend_schema(request=s.DescriptionSerializer, responses={201: dict})
    def perform_idempotent(self, request):  # type: ignore[no-untyped-def]
        data = s.DescriptionSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        desc = services.submit_description(account=request.user, text=data.validated_data["text"])
        body = json.loads(json.dumps(s.description_payload(desc), cls=JSONEncoder))
        return status.HTTP_201_CREATED, body

    @extend_schema(responses={200: dict})
    def get(self, request):  # type: ignore[no-untyped-def]
        profile = services.get_or_create_profile(account=request.user)
        items = [
            {**s.description_payload(d), "text": d.text}
            for d in profile.descriptions.order_by("-version")[:20]
        ]
        return Response(
            {
                "items": items,
                "current_version": profile.current_description.version
                if profile.current_description
                else None,
                "next_cursor": None,
            }
        )


class PreferencesView(APIView):
    permission_classes = [IsActiveMember]

    @extend_schema(responses={200: dict})
    def get(self, request):  # type: ignore[no-untyped-def]
        profile = services.get_or_create_profile(account=request.user)
        return Response(s.preference_payload(preferences.get_or_create_preference(profile=profile)))

    @extend_schema(request=s.PreferenceSerializer, responses={200: dict})
    def put(self, request):  # type: ignore[no-untyped-def]
        data = s.PreferenceSerializer(data=request.data, partial=True)
        reject_unknown_fields(data, request.data)
        data.is_valid(raise_exception=True)
        return Response(
            s.preference_payload(
                preferences.set_preferences(account=request.user, data=dict(data.validated_data))
            )
        )


class PhotosView(IdempotentMixin):
    permission_classes = [IsActiveMember]

    @extend_schema(request=s.PhotoCreateSerializer, responses={201: dict})
    def perform_idempotent(self, request):  # type: ignore[no-untyped-def]
        data = s.PhotoCreateSerializer(data=request.data)
        reject_unknown_fields(data, request.data)
        data.is_valid(raise_exception=True)
        photo = photos.add_photo(account=request.user, media_id=data.validated_data["media_id"])
        body = json.loads(json.dumps(s.photo_payload(photo, request.user), cls=JSONEncoder))
        return status.HTTP_201_CREATED, body

    @extend_schema(responses={200: dict})
    def get(self, request):  # type: ignore[no-untyped-def]
        profile = services.get_or_create_profile(account=request.user)
        items = [s.photo_payload(p, request.user) for p in profile.photos.select_related("media")]
        return Response({"items": items, "next_cursor": None})


class PhotoDetailView(APIView):
    permission_classes = [IsActiveMember]

    @extend_schema(responses={204: None})
    def delete(self, request, photo_id):  # type: ignore[no-untyped-def]
        photos.delete_photo(account=request.user, photo_id=photo_id)
        return Response(status=status.HTTP_204_NO_CONTENT)


class PhotoOrderView(APIView):
    permission_classes = [IsActiveMember]

    @extend_schema(request=s.PhotoOrderSerializer, responses={200: dict})
    def put(self, request):  # type: ignore[no-untyped-def]
        data = s.PhotoOrderSerializer(data=request.data)
        reject_unknown_fields(data, request.data)
        data.is_valid(raise_exception=True)
        ordered = photos.reorder_photos(
            account=request.user, ordered_ids=data.validated_data["ids"]
        )
        return Response(
            {"items": [s.photo_payload(p, request.user) for p in ordered], "next_cursor": None}
        )


class GoLiveView(APIView):
    permission_classes = [IsActiveMember]

    @extend_schema(request=None, responses={200: dict})
    def post(self, request):  # type: ignore[no-untyped-def]
        return Response(s.own_profile(services.go_live(account=request.user)))


class HideView(APIView):
    permission_classes = [IsActiveMember]
    hidden = True

    @extend_schema(request=None, responses={200: dict})
    def post(self, request):  # type: ignore[no-untyped-def]
        return Response(
            s.own_profile(services.set_hidden(account=request.user, hidden=self.hidden))
        )


class UnhideView(HideView):
    hidden = False

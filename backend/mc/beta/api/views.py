from drf_spectacular.utils import extend_schema
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from mc.accounts.permissions import IsActiveMember
from mc.common.serializers import reject_unknown_fields

from .. import services
from . import serializers as s


class FeedbackView(APIView):
    permission_classes = [IsActiveMember]

    @extend_schema(request=s.FeedbackSerializer, responses={201: None})
    def post(self, request):  # type: ignore[no-untyped-def]
        data = s.FeedbackSerializer(data=request.data)
        reject_unknown_fields(data, request.data)
        data.is_valid(raise_exception=True)
        services.submit_feedback(account_id=request.user.id, **data.validated_data)
        return Response(status=status.HTTP_201_CREATED)

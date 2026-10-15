import json

from drf_spectacular.utils import extend_schema
from rest_framework import status
from rest_framework.response import Response
from rest_framework.utils.encoders import JSONEncoder
from rest_framework.views import APIView

from mc.accounts import services as account_services
from mc.accounts.permissions import IsAuthenticatedAnyStatus
from mc.common.net import client_ip
from mc.privacy import export


class ReauthStartView(APIView):
    permission_classes = [IsAuthenticatedAnyStatus]

    @extend_schema(request=None, responses={202: dict})
    def post(self, request):  # type: ignore[no-untyped-def]
        account_services.start_reauth(account=request.user, ip=client_ip(request))
        return Response({"status": "accepted"}, status=status.HTTP_202_ACCEPTED)


class ExportView(APIView):
    permission_classes = [IsAuthenticatedAnyStatus]

    @extend_schema(request=None, responses={202: dict})
    def post(self, request):  # type: ignore[no-untyped-def]
        req = export.request_export(account=request.user)
        return Response(
            json.loads(
                json.dumps(
                    {"id": str(req.id), "status": req.status, "due_at": req.due_at}, cls=JSONEncoder
                )
            ),
            status=status.HTTP_202_ACCEPTED,
        )


class ExportDetailView(APIView):
    permission_classes = [IsAuthenticatedAnyStatus]

    @extend_schema(responses={200: dict})
    def get(self, request, request_id):  # type: ignore[no-untyped-def]
        from mc.common.errors import NotFound
        from mc.privacy.models import PrivacyRequest

        req = PrivacyRequest.objects.filter(
            id=request_id, account_ref=request.user.id, kind="export"
        ).first()
        if req is None:
            raise NotFound()
        body: dict = {"id": str(req.id), "status": req.status, "due_at": req.due_at}
        if req.status == "completed" and req.file_key:
            url, expires = export.signed_link(account=request.user, request_id=request_id)
            body |= {"url": url, "expires_at": expires}
        return Response(json.loads(json.dumps(body, cls=JSONEncoder)))

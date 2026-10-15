from drf_spectacular.utils import extend_schema
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from mc.accounts import selectors, services
from mc.accounts.models import Account
from mc.accounts.policies import can_manage_session
from mc.common.errors import NotFound
from mc.common.net import client_ip
from mc.verification import selectors as verification_selectors

from . import serializers as s


def _account_summary(account: Account) -> dict[str, object]:
    return {
        "id": str(account.id),
        "phone": account.phone_e164,  # returned to its owner only
        "email": account.email,
        "email_verified": account.email_verified_at is not None,
        "status": account.status,
        "locale": account.locale,
        "verification_status": verification_selectors.latest_status(account)["status"],
        "profile_status": "none",  # wired to the profiles module in MC-045
    }


def _auth_payload(result: services.AuthResult) -> dict[str, object]:
    return {
        "access": result.access,
        "refresh": result.refresh,
        "account": _account_summary(result.account),
    }


class OtpStartView(APIView):
    permission_classes = [AllowAny]
    authentication_classes: list = []

    @extend_schema(request=s.OtpStartSerializer, responses={202: dict}, auth=[])
    def post(self, request):  # type: ignore[no-untyped-def]
        data = s.OtpStartSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        services.start_otp(
            phone=data.validated_data["phone"],
            purpose=data.validated_data["purpose"],
            ip=client_ip(request),
        )
        return Response({"status": "accepted"}, status=status.HTTP_202_ACCEPTED)


class OtpVerifyView(APIView):
    permission_classes = [AllowAny]
    authentication_classes: list = []

    @extend_schema(request=s.OtpVerifySerializer, responses={200: dict, 201: dict}, auth=[])
    def post(self, request):  # type: ignore[no-untyped-def]
        data = s.OtpVerifySerializer(data=request.data)
        data.is_valid(raise_exception=True)
        device = data.validated_data.get("device")
        result = services.verify_otp(
            phone=data.validated_data["phone"],
            code=data.validated_data["code"],
            ip=client_ip(request),
            device=dict(device) if device else None,
        )
        return Response(
            _auth_payload(result),
            status=status.HTTP_201_CREATED if result.created else status.HTTP_200_OK,
        )


class RefreshView(APIView):
    permission_classes = [AllowAny]
    authentication_classes: list = []

    @extend_schema(request=s.RefreshSerializer, responses={200: dict}, auth=[])
    def post(self, request):  # type: ignore[no-untyped-def]
        data = s.RefreshSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        result = services.refresh_session(refresh_token=data.validated_data["refresh"])
        return Response(_auth_payload(result))


class LogoutView(APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(request=None, responses={204: None})
    def post(self, request):  # type: ignore[no-untyped-def]
        services.revoke_session(session=request.session_obj, reason="logout")
        return Response(status=status.HTTP_204_NO_CONTENT)


class MeView(APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(responses={200: dict})
    def get(self, request):  # type: ignore[no-untyped-def]
        return Response(_account_summary(request.user))


class SessionsView(APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(responses={200: dict})
    def get(self, request):  # type: ignore[no-untyped-def]
        current = request.session_obj.id
        items = [
            {
                "id": str(sess.id),
                "current": sess.id == current,
                "platform": sess.device.platform if sess.device else None,
                "app_version": sess.device.app_version if sess.device else None,
                "issued_at": sess.issued_at,
                "expires_at": sess.expires_at,
            }
            for sess in selectors.active_sessions(request.user)
        ]
        return Response({"items": items, "next_cursor": None})


class SessionDetailView(APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(responses={204: None})
    def delete(self, request, session_id):  # type: ignore[no-untyped-def]
        from mc.accounts.models import Session

        sess = Session.objects.filter(id=session_id).first()
        if sess is None or not can_manage_session(request.user, sess):
            raise NotFound()  # never reveal other accounts' session ids
        services.revoke_session(session=sess)
        return Response(status=status.HTTP_204_NO_CONTENT)


class ConsentsView(APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(request=s.ConsentsSerializer, responses={201: dict})
    def post(self, request):  # type: ignore[no-untyped-def]
        data = s.ConsentsSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        services.record_consent(
            account=request.user,
            items=[dict(i) for i in data.validated_data["consents"]],
            source=data.validated_data["source"],
            ip=client_ip(request),
        )
        current = selectors.current_consents(request.user)
        return Response(
            {
                "consents": {
                    k: {"version": v.version, "granted": v.granted} for k, v in current.items()
                }
            },
            status=status.HTTP_201_CREATED,
        )


class DevicesView(APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(request=s.RegisterDeviceSerializer, responses={200: dict})
    def post(self, request):  # type: ignore[no-untyped-def]
        data = s.RegisterDeviceSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        device = services.register_device(account=request.user, **data.validated_data)
        return Response({"id": str(device.id)})

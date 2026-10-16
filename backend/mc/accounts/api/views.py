from drf_spectacular.utils import extend_schema
from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from mc.accounts import recovery, selectors, services
from mc.accounts.models import Account
from mc.accounts.permissions import IsActiveMember, IsAuthenticatedAnyStatus
from mc.accounts.policies import can_manage_session
from mc.common.errors import NotFound
from mc.common.net import client_ip
from mc.common.serializers import reject_unknown_fields
from mc.profiles import selectors as profile_selectors
from mc.safety import enforcement as safety_enforcement
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
        "profile_status": profile_selectors.status_for(account),
        "enforcement": safety_enforcement.enforcement_status(account),
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
            invite_code=data.validated_data.get("invite_code") or None,
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
    permission_classes = [IsAuthenticatedAnyStatus]

    @extend_schema(request=None, responses={204: None})
    def post(self, request):  # type: ignore[no-untyped-def]
        services.revoke_session(session=request.session_obj, reason="logout")
        return Response(status=status.HTTP_204_NO_CONTENT)


class MeView(APIView):
    permission_classes = [IsAuthenticatedAnyStatus]

    @extend_schema(responses={200: dict})
    def get(self, request):  # type: ignore[no-untyped-def]
        return Response(_account_summary(request.user))

    @extend_schema(request=None, responses={200: dict})
    def delete(self, request):  # type: ignore[no-untyped-def]
        """Delete my account: needs a fresh OTP (`POST /me/reauth/start`). Deactivates now, erases after the grace period."""
        import json

        from rest_framework.utils.encoders import JSONEncoder

        from mc.common.errors import ValidationFailed
        from mc.privacy import services as privacy_services

        code = request.data.get("code") if isinstance(request.data, dict) else None
        if (
            set(request.data) - {"code"}
            or not isinstance(code, str)
            or not code.isdigit()
            or len(code) != 6
        ):
            raise ValidationFailed("Send the 6-digit confirmation code.")
        _req, body = privacy_services.request_deletion(account=request.user, code=code)
        return Response(json.loads(json.dumps(body, cls=JSONEncoder)))


class SessionsView(APIView):
    permission_classes = [IsAuthenticatedAnyStatus]

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
    permission_classes = [IsAuthenticatedAnyStatus]

    @extend_schema(responses={204: None})
    def delete(self, request, session_id):  # type: ignore[no-untyped-def]
        from mc.accounts.models import Session

        sess = Session.objects.filter(id=session_id).first()
        if sess is None or not can_manage_session(request.user, sess):
            raise NotFound()  # never reveal other accounts' session ids
        services.revoke_session(session=sess)
        return Response(status=status.HTTP_204_NO_CONTENT)


class ConsentsView(APIView):
    permission_classes = [IsAuthenticatedAnyStatus]

    @extend_schema(responses={200: dict})
    def get(self, request):  # type: ignore[no-untyped-def]
        current = selectors.current_consents(request.user)
        return Response(
            {
                "consents": {
                    k: {"version": v.version, "granted": v.granted} for k, v in current.items()
                }
            }
        )

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
    permission_classes = [IsAuthenticatedAnyStatus]

    @extend_schema(responses={200: dict})
    def get(self, request):  # type: ignore[no-untyped-def]
        """My registered devices. Never returns the push token itself, only whether one is registered."""
        items = [
            {
                "id": str(d.id),
                "install_id": str(d.install_id),
                "platform": d.platform,
                "app_version": d.app_version,
                "os_version": d.os_version,
                "push_enabled": bool(d.push_token),
                "trusted": d.trusted,
                "first_seen_at": d.first_seen_at,
                "last_seen_at": d.last_seen_at,
            }
            for d in selectors.devices_for(request.user)
        ]
        return Response({"items": items, "next_cursor": None})

    @extend_schema(request=s.RegisterDeviceSerializer, responses={200: dict})
    def post(self, request):  # type: ignore[no-untyped-def]
        data = s.RegisterDeviceSerializer(data=request.data)
        data.is_valid(raise_exception=True)
        values = dict(data.validated_data)
        clear = "push_token" in values and values["push_token"] is None
        device = services.register_device(
            account=request.user,
            push_token=values.pop("push_token", None),
            clear_push_token=clear,
            **values,
        )
        return Response({"id": str(device.id)})


class EmailStartView(APIView):
    permission_classes = [IsActiveMember]

    @extend_schema(request=s.EmailStartSerializer, responses={202: dict})
    def post(self, request):  # type: ignore[no-untyped-def]
        data = s.EmailStartSerializer(data=request.data)
        reject_unknown_fields(data, request.data)
        data.is_valid(raise_exception=True)
        recovery.start_email_verification(
            account=request.user, email=data.validated_data["email"], ip=client_ip(request)
        )
        return Response({"status": "accepted"}, status=status.HTTP_202_ACCEPTED)


class EmailVerifyView(APIView):
    permission_classes = [IsActiveMember]

    @extend_schema(request=s.CodeSerializer, responses={200: dict})
    def post(self, request):  # type: ignore[no-untyped-def]
        data = s.CodeSerializer(data=request.data)
        reject_unknown_fields(data, request.data)
        data.is_valid(raise_exception=True)
        acct = recovery.confirm_email(account=request.user, code=data.validated_data["code"])
        return Response(_account_summary(acct))


class _PublicPost(APIView):
    permission_classes = [AllowAny]
    authentication_classes: list = []
    serializer: type = s.RecoverStartSerializer

    def parsed(self, request):  # type: ignore[no-untyped-def]
        data = self.serializer(data=request.data)
        reject_unknown_fields(data, request.data)
        data.is_valid(raise_exception=True)
        return data.validated_data


class RecoverStartView(_PublicPost):
    serializer = s.RecoverStartSerializer

    @extend_schema(request=s.RecoverStartSerializer, responses={202: dict}, auth=[])
    def post(self, request):  # type: ignore[no-untyped-def]
        recovery.start_recovery(phone=self.parsed(request)["phone"], ip=client_ip(request))
        return Response({"status": "accepted"}, status=status.HTTP_202_ACCEPTED)


class RecoverVerifyEmailView(_PublicPost):
    serializer = s.RecoverVerifyEmailSerializer

    @extend_schema(request=s.RecoverVerifyEmailSerializer, responses={200: dict}, auth=[])
    def post(self, request):  # type: ignore[no-untyped-def]
        v = self.parsed(request)
        token, params = recovery.verify_email(phone=v["phone"], code=v["code"])
        return Response({"recovery_token": token, "sdk_params": params})


class RecoverStatusView(_PublicPost):
    serializer = s.RecoveryTokenSerializer

    @extend_schema(request=s.RecoveryTokenSerializer, responses={200: dict}, auth=[])
    def post(self, request):  # type: ignore[no-untyped-def]
        return Response(
            {"state": recovery.biometric_state(token=self.parsed(request)["recovery_token"])}
        )


class RecoverNewPhoneView(_PublicPost):
    serializer = s.RecoverNewPhoneSerializer

    @extend_schema(request=s.RecoverNewPhoneSerializer, responses={202: dict}, auth=[])
    def post(self, request):  # type: ignore[no-untyped-def]
        v = self.parsed(request)
        recovery.start_new_phone(
            token=v["recovery_token"], new_phone=v["new_phone"], ip=client_ip(request)
        )
        return Response({"status": "accepted"}, status=status.HTTP_202_ACCEPTED)


class RecoverCompleteView(_PublicPost):
    serializer = s.RecoverCompleteSerializer

    @extend_schema(request=s.RecoverCompleteSerializer, responses={200: dict}, auth=[])
    def post(self, request):  # type: ignore[no-untyped-def]
        v = self.parsed(request)
        recovery.complete(token=v["recovery_token"], code=v["code"], ip=client_ip(request))
        return Response({"status": "phone_changed"})

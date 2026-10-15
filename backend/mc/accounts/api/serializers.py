from rest_framework import serializers

from mc.accounts.models import ConsentRecord, Device


class OtpStartSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=32)
    purpose = serializers.ChoiceField(choices=["login", "recover"], default="login")


class DeviceInfoSerializer(serializers.Serializer):
    install_id = serializers.UUIDField()
    platform = serializers.ChoiceField(choices=Device.Platform.values)
    app_version = serializers.CharField(max_length=32, required=False, allow_blank=True, default="")
    os_version = serializers.CharField(max_length=32, required=False, allow_blank=True, default="")


class OtpVerifySerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=32)
    code = serializers.RegexField(r"^\d{6}$", max_length=6)
    device = DeviceInfoSerializer(required=False)


class RefreshSerializer(serializers.Serializer):
    refresh = serializers.CharField(max_length=128)


class ConsentItemSerializer(serializers.Serializer):
    kind = serializers.ChoiceField(choices=ConsentRecord.Kind.values)
    version = serializers.CharField(max_length=20)
    granted = serializers.BooleanField()


class ConsentsSerializer(serializers.Serializer):
    consents = ConsentItemSerializer(many=True, allow_empty=False)
    source = serializers.ChoiceField(choices=ConsentRecord.Source.values, default="app")  # type: ignore[assignment]

    def validate_consents(self, value: list) -> list:
        if len(value) > 10:
            raise serializers.ValidationError("Too many items.")
        return value


class RegisterDeviceSerializer(DeviceInfoSerializer):
    push_token = serializers.CharField(
        max_length=512, allow_null=True, required=False, default=None
    )


class EmailStartSerializer(serializers.Serializer):
    email = serializers.EmailField(max_length=254)


class CodeSerializer(serializers.Serializer):
    code = serializers.RegexField(r"^\d{6}$", max_length=6)


class RecoverStartSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=32)


class RecoverVerifyEmailSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=32)
    code = serializers.RegexField(r"^\d{6}$", max_length=6)


class RecoveryTokenSerializer(serializers.Serializer):
    recovery_token = serializers.CharField(max_length=500)


class RecoverNewPhoneSerializer(RecoveryTokenSerializer):
    new_phone = serializers.CharField(max_length=32)


class RecoverCompleteSerializer(RecoveryTokenSerializer):
    code = serializers.RegexField(r"^\d{6}$", max_length=6)

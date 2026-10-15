from rest_framework import serializers


class CreateSessionSerializer(serializers.Serializer):
    id_type = serializers.CharField(max_length=30, required=False, allow_blank=True, default="")
    issuing_country = serializers.RegexField(
        r"^[A-Za-z]{2}$", required=False, allow_blank=True, default=""
    )


class AppealSerializer(serializers.Serializer):
    attempt_id = serializers.UUIDField(required=False, allow_null=True)
    message = serializers.CharField(max_length=1200)

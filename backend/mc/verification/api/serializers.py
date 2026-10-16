from drf_spectacular.utils import extend_schema_serializer
from rest_framework import serializers


class CreateSessionSerializer(serializers.Serializer):
    id_type = serializers.CharField(max_length=30, required=False, allow_blank=True, default="")
    issuing_country = serializers.RegexField(
        r"^[A-Za-z]{2}$", required=False, allow_blank=True, default=""
    )


@extend_schema_serializer(component_name="VerificationAppeal")
class AppealSerializer(serializers.Serializer):
    attempt_id = serializers.UUIDField(required=False, allow_null=True)
    # 10-1,000 characters, as `review.open_appeal` enforces
    message = serializers.CharField(min_length=10, max_length=1000)

from drf_spectacular.utils import extend_schema_serializer
from rest_framework import serializers


class BlockSerializer(serializers.Serializer):
    profile_id = serializers.UUIDField()


class ReportSerializer(serializers.Serializer):
    profile_id = serializers.UUIDField()
    category = serializers.CharField(max_length=20)
    context_type = serializers.ChoiceField(choices=["profile", "interest", "message"])
    context_id = serializers.UUIDField(required=False, allow_null=True)
    text = serializers.CharField(max_length=1000, required=False, allow_blank=True, default="")
    also_block = serializers.BooleanField(required=False, default=False)


@extend_schema_serializer(component_name="SafetyAppeal")
class AppealSerializer(serializers.Serializer):
    action_id = serializers.UUIDField()
    # 10-1,000 characters, as `enforcement.open_appeal` enforces
    message = serializers.CharField(min_length=10, max_length=1000)

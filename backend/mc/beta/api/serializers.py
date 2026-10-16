from drf_spectacular.utils import extend_schema_serializer
from rest_framework import serializers


@extend_schema_serializer(component_name="BetaFeedback")
class FeedbackSerializer(serializers.Serializer):
    message = serializers.CharField(
        min_length=3, max_length=2000
    )  # 3-2,000 as `submit_feedback` enforces
    screen = serializers.CharField(max_length=40, required=False, allow_blank=True, default="")
    rating = serializers.IntegerField(
        min_value=1, max_value=5, required=False, allow_null=True, default=None
    )
    app_version = serializers.CharField(max_length=32, required=False, allow_blank=True, default="")

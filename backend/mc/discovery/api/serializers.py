from drf_spectacular.utils import extend_schema_serializer
from rest_framework import serializers


@extend_schema_serializer(component_name="DiscoveryFeedback")
class FeedbackSerializer(serializers.Serializer):
    profile_id = serializers.UUIDField()
    action = serializers.ChoiceField(choices=["pass", "not_relevant"])

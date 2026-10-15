from rest_framework import serializers


class FeedbackSerializer(serializers.Serializer):
    profile_id = serializers.UUIDField()
    action = serializers.ChoiceField(choices=["pass", "not_relevant"])

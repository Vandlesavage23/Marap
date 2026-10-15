from rest_framework import serializers


class FeedbackSerializer(serializers.Serializer):
    message = serializers.CharField(max_length=2000)
    screen = serializers.CharField(max_length=40, required=False, allow_blank=True, default="")
    rating = serializers.IntegerField(
        min_value=1, max_value=5, required=False, allow_null=True, default=None
    )
    app_version = serializers.CharField(max_length=32, required=False, allow_blank=True, default="")

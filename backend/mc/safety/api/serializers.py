from rest_framework import serializers


class BlockSerializer(serializers.Serializer):
    profile_id = serializers.UUIDField()


class ReportSerializer(serializers.Serializer):
    profile_id = serializers.UUIDField()
    category = serializers.CharField(max_length=20)
    context_type = serializers.ChoiceField(choices=["profile", "interest", "message"])
    context_id = serializers.UUIDField(required=False, allow_null=True)
    text = serializers.CharField(max_length=1200, required=False, allow_blank=True, default="")
    also_block = serializers.BooleanField(required=False, default=False)


class AppealSerializer(serializers.Serializer):
    action_id = serializers.UUIDField()
    message = serializers.CharField(max_length=1200)

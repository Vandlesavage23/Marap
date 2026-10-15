from rest_framework import serializers


class SendMessageSerializer(serializers.Serializer):
    client_msg_id = serializers.UUIDField()
    kind = serializers.ChoiceField(choices=["text", "image", "voice"])
    body = serializers.CharField(
        max_length=4000, required=False, allow_blank=True, allow_null=True, trim_whitespace=False
    )
    media_id = serializers.UUIDField(required=False, allow_null=True)


class ReadSerializer(serializers.Serializer):
    up_to_message_id = serializers.UUIDField()

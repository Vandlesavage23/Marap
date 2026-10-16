from django.conf import settings
from drf_spectacular.utils import extend_schema_serializer
from rest_framework import serializers


class SendMessageSerializer(serializers.Serializer):
    client_msg_id = serializers.UUIDField()
    kind = serializers.ChoiceField(choices=["text", "image", "voice"])
    body = serializers.CharField(
        max_length=settings.MESSAGE_MAX_CHARS,
        required=False,
        allow_blank=True,
        allow_null=True,
        trim_whitespace=False,
    )
    media_id = serializers.UUIDField(required=False, allow_null=True)


@extend_schema_serializer(component_name="MessagesRead")
class ReadSerializer(serializers.Serializer):
    up_to_message_id = serializers.UUIDField()

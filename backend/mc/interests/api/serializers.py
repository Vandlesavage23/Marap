from rest_framework import serializers


class SendInterestSerializer(serializers.Serializer):
    # The recipient's public profile id (accounts ids are never exposed to other members).
    recipient_id = serializers.UUIDField()

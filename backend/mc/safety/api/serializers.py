from rest_framework import serializers


class BlockSerializer(serializers.Serializer):
    profile_id = serializers.UUIDField()

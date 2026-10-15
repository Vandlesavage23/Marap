from rest_framework import serializers

from mc.media.models import MediaObject


class UploadRequestSerializer(serializers.Serializer):
    purpose = serializers.ChoiceField(choices=MediaObject.Purpose.values)
    mime = serializers.CharField(max_length=40)
    bytes = serializers.IntegerField(min_value=1)
    sha256 = serializers.CharField(max_length=64, required=False, allow_blank=True, default="")

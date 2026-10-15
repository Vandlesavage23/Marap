from rest_framework import serializers


class AnswerItemSerializer(serializers.Serializer):
    question = serializers.CharField(max_length=60)
    value = serializers.JSONField()
    importance = serializers.IntegerField(min_value=1, max_value=3, required=False, default=2)
    is_dealbreaker = serializers.BooleanField(required=False, default=False)


class AnswersSerializer(serializers.Serializer):
    answers = AnswerItemSerializer(many=True, allow_empty=False)

    def validate_answers(self, value: list) -> list:
        if len(value) > 60:
            raise serializers.ValidationError("Too many answers.")
        return value

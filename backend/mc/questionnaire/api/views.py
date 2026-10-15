from drf_spectacular.utils import extend_schema
from rest_framework.response import Response
from rest_framework.views import APIView

from mc.accounts.permissions import IsActiveMember
from mc.common.serializers import reject_unknown_fields
from mc.questionnaire import selectors, services
from mc.questionnaire.models import Answer

from . import serializers as s


def question_payload(q) -> dict[str, object]:  # type: ignore[no-untyped-def]
    return {
        "key": q.key,
        "version": q.version,
        "dimension": q.dimension,
        "type": q.type,
        "prompt": q.prompt,
        "options": q.options,
        "is_core": q.is_core,
        "is_special": q.is_special,
        "consent_required": q.consent_kind or None,
        "allow_dealbreaker": q.allow_dealbreaker,
    }


class QuestionsView(APIView):
    permission_classes = [IsActiveMember]

    @extend_schema(responses={200: dict})
    def get(self, request):  # type: ignore[no-untyped-def]
        return Response(
            {
                "items": [question_payload(q) for q in selectors.active_questions()],
                "next_cursor": None,
            }
        )


class MyAnswersView(APIView):
    permission_classes = [IsActiveMember]

    @extend_schema(responses={200: dict})
    def get(self, request):  # type: ignore[no-untyped-def]
        rows = Answer.objects.filter(account=request.user).select_related("question")
        return Response(
            {
                "items": [
                    {
                        "question": a.question.key,
                        "value": selectors.answer_value(a),
                        "importance": a.importance,
                        "is_dealbreaker": a.is_dealbreaker,
                        "stale": a.question_version != a.question.version,
                    }
                    for a in rows
                ],
                "core_complete": selectors.core_complete(request.user.id),
                "next_cursor": None,
            }
        )

    @extend_schema(request=s.AnswersSerializer, responses={200: dict})
    def put(self, request):  # type: ignore[no-untyped-def]
        data = s.AnswersSerializer(data=request.data)
        reject_unknown_fields(data, request.data)
        data.is_valid(raise_exception=True)
        services.save_answers(
            account=request.user, answers=[dict(a) for a in data.validated_data["answers"]]
        )
        return self.get(request)

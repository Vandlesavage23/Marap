import json
import uuid
from collections.abc import Iterable
from typing import Any

from django.db.models import QuerySet

from .models import Answer, Question


def active_questions() -> QuerySet[Question]:
    return Question.objects.filter(active=True).order_by("position", "key")


def core_question_ids() -> set[uuid.UUID]:
    return set(active_questions().filter(is_core=True).values_list("id", flat=True))


def core_complete(account_id: uuid.UUID) -> bool:
    """All active core questions answered at their current version."""
    core = list(active_questions().filter(is_core=True).values_list("id", "version"))
    if not core:
        return False
    answered = {
        a.question_id
        for a in Answer.objects.filter(
            account_id=account_id, question__is_core=True, question__active=True
        ).select_related("question")
        if a.question_version == a.question.version
    }
    return all(qid in answered for qid, _ in core)


def answer_value(answer: Answer) -> Any:
    return json.loads(answer.value_enc) if answer.value_enc is not None else answer.value


def answers_for_scoring(
    account_ids: Iterable[uuid.UUID],
) -> dict[uuid.UUID, dict[str, dict[str, Any]]]:
    """`{account_id: {question_key: {value, importance, dimension, scoring, is_dealbreaker}}}`.

    Special data is excluded unless the question is explicitly `scoring_allowed` (e.g. the faith-match
    answer the user chose to give). Money attitudes and anything else special never appear here.
    Stale answers (older question version) are skipped."""
    out: dict[uuid.UUID, dict[str, dict[str, Any]]] = {}
    qs = (
        Answer.objects.filter(account_id__in=list(account_ids), question__active=True)
        .select_related("question")
        .order_by("id")
    )
    for a in qs:
        q = a.question
        if a.question_version != q.version or (q.is_special and not q.scoring_allowed):
            continue
        out.setdefault(a.account_id, {})[q.key] = {
            "value": answer_value(a),
            "importance": a.importance,
            "dimension": q.dimension,
            "scoring": q.scoring,
            "is_dealbreaker": a.is_dealbreaker,
        }
    return out

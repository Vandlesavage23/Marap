"""Answer writes (Bible §7.4). Special answers need consent and are stored encrypted."""

import json
from typing import TYPE_CHECKING, Any

from django.db import transaction

from mc.accounts import selectors as account_selectors
from mc.common.errors import ValidationFailed
from mc.verification import selectors as verification_selectors

from .models import Answer, Question

if TYPE_CHECKING:
    from mc.accounts.models import Account


def validate_value(q: Question, value: Any) -> Any:
    if q.type == Question.Type.SINGLE:
        allowed = {o["value"] for o in q.options}
        if not isinstance(value, str) or value not in allowed:
            raise ValidationFailed(f"Invalid answer for {q.key}.", question=q.key)
        return value
    if q.type == Question.Type.MULTI:
        allowed = {o["value"] for o in q.options}
        if (
            not isinstance(value, list)
            or not value
            or len(set(value)) != len(value)
            or not set(value) <= allowed
        ):
            raise ValidationFailed(f"Invalid answer for {q.key}.", question=q.key)
        return sorted(value)
    lo, hi = q.options["min"], q.options["max"]
    if isinstance(value, bool) or not isinstance(value, int) or not lo <= value <= hi:
        raise ValidationFailed(f"Invalid answer for {q.key}.", question=q.key)
    return value


def save_answers(*, account: "Account", answers: list[dict[str, Any]]) -> list[Answer]:
    """Upsert answers (all-or-nothing). Each item: `{question, value, importance?, is_dealbreaker?}`."""
    if not verification_selectors.is_verified_adult(account):
        from mc.common.errors import NotVerified

        raise NotVerified("Verify your identity before answering the questionnaire.")
    if not answers:
        raise ValidationFailed("No answers supplied.")
    keys = [a["question"] for a in answers]
    if len(set(keys)) != len(keys):
        raise ValidationFailed("Each question may appear once.")
    questions = {q.key: q for q in Question.objects.filter(key__in=keys, active=True)}
    saved = []
    with transaction.atomic():
        for item in answers:
            q = questions.get(item["question"])
            if q is None:
                raise ValidationFailed(f"Unknown question: {item['question']}")
            value = validate_value(q, item["value"])
            importance = item.get("importance", 2)
            if importance not in (1, 2, 3):
                raise ValidationFailed("Importance must be 1, 2 or 3.", question=q.key)
            dealbreaker = bool(item.get("is_dealbreaker", False))
            if dealbreaker and not q.allow_dealbreaker:
                raise ValidationFailed("This question can't be a deal-breaker.", question=q.key)
            fields: dict[str, Any] = {
                "question_version": q.version,
                "importance": importance,
                "is_dealbreaker": dealbreaker,
            }
            if q.is_special:
                if not account_selectors.has_consent(account, q.consent_kind):
                    raise ValidationFailed(
                        "Please give consent before answering this optional question.",
                        question=q.key,
                        missing_consent=q.consent_kind,
                    )
                fields |= {"value": None, "value_enc": json.dumps(value)}
            else:
                fields |= {"value": value, "value_enc": None}
            ans, _ = Answer.objects.update_or_create(account=account, question=q, defaults=fields)
            saved.append(ans)
    return saved


def delete_special_answers(*, account_id, consent_kind: str) -> int:  # type: ignore[no-untyped-def]
    """Consent withdrawn → remove those answers (they also leave scoring)."""
    deleted, _ = Answer.objects.filter(
        account_id=account_id, question__is_special=True, question__consent_kind=consent_kind
    ).delete()
    return deleted

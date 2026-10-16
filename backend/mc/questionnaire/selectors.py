import contextlib
import hashlib
import json
import uuid
from collections.abc import Iterable
from typing import Any

import redis
from django.db.models import QuerySet

from . import scoring_cache
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


_PLAIN_COLUMNS = (
    "id", "account_id", "question_id", "question_version", "value", "importance", "is_dealbreaker"
)  # fmt: skip
_SPECIAL_COLUMNS = (
    "id", "account_id", "question_id", "question_version", "value", "value_enc", "importance",
    "is_dealbreaker",
)  # fmt: skip


def _question_signature(plain: dict[str, tuple[Any, ...]]) -> str:
    """Changes whenever the set/version/content of cacheable questions changes (re-seed)."""
    blob = json.dumps(sorted(plain.values(), key=lambda r: r[1]), default=str, sort_keys=True)
    return hashlib.sha1(blob.encode(), usedforsecurity=False).hexdigest()[:12]


def _consented_special_rows(
    ids: list[uuid.UUID], question_ids: list[str], qinfo: dict[str, tuple[str, int, str, Any]]
) -> dict[uuid.UUID, list[list[Any]]]:
    """Answers to special questions flagged `scoring_allowed` (decrypted here, in process memory only).
    Same row shape as the cached non-special vectors."""
    out: dict[uuid.UUID, list[list[Any]]] = {}
    qs = (
        Answer.objects.filter(account_id__in=ids, question_id__in=question_ids)
        .order_by("id")
        .values_list(*_SPECIAL_COLUMNS)
    )
    for aid, acct, qid, qver, value, value_enc, importance, dealbreaker in qs:
        key, version = qinfo[str(qid)][:2]
        if qver != version:
            continue
        decoded = json.loads(value_enc) if value_enc is not None else value
        out.setdefault(acct, []).append([str(aid), key, decoded, importance, dealbreaker])
    return out


def answers_for_scoring(
    account_ids: Iterable[uuid.UUID],
) -> dict[uuid.UUID, dict[str, dict[str, Any]]]:
    """`{account_id: {question_key: {value, importance, dimension, scoring, is_dealbreaker}}}`.

    Special data is excluded unless the question is explicitly `scoring_allowed` (e.g. the faith-match
    answer the user chose to give). Money attitudes and anything else special never appear here.
    Stale answers (older question version) are skipped.

    Perf: no model instances; question rows are read once; non-special answer vectors come from the
    per-account Redis cache (`scoring_cache`) and only misses hit the database. Special answers that are
    allowed in scoring are read from the database every call and are never cached. Per-account entry
    order is by answer id, exactly as the original ORM implementation (it fixes float summation order)."""
    ids = list(
        dict.fromkeys(a if isinstance(a, uuid.UUID) else uuid.UUID(str(a)) for a in account_ids)
    )
    if not ids:
        return {}
    plain: dict[str, tuple[Any, ...]] = {}  # id -> (id, key, version, dimension, scoring)
    qinfo: dict[
        str, tuple[str, int, str, dict[str, Any]]
    ] = {}  # id -> (key, version, dim, scoring)
    special_ok: list[str] = []
    for (
        qid,
        key,
        version,
        dim,
        scoring,
        is_special,
        scoring_allowed,
    ) in active_questions().values_list(
        "id", "key", "version", "dimension", "scoring", "is_special", "scoring_allowed"
    ):
        if is_special and not scoring_allowed:
            continue
        sqid = str(qid)
        qinfo[sqid] = (key, version, dim, scoring)
        if is_special:
            special_ok.append(sqid)
        else:
            plain[sqid] = (sqid, key, version, dim, scoring)
    by_key = {k: (v, d, sc) for k, v, d, sc in qinfo.values()}

    # --- non-special answers: cache → database for misses
    rows: dict[uuid.UUID, list[list[Any]]] = {}
    use_cache = scoring_cache.enabled() and bool(plain)
    vers: dict[uuid.UUID, int] = {}
    if use_cache:
        sig = _question_signature(plain)
        try:
            vers = scoring_cache.versions(ids)
            rows = scoring_cache.load(sig, ids, vers)
        except redis.RedisError:
            use_cache, rows = False, {}
    misses = [a for a in ids if a not in rows]
    if misses and plain:
        fresh: dict[uuid.UUID, list[list[Any]]] = {a: [] for a in misses}
        qs = (
            Answer.objects.filter(account_id__in=misses, question_id__in=list(plain))
            .order_by("id")
            .values_list(*_PLAIN_COLUMNS)
        )
        for aid, acct, qid, qver, value, importance, dealbreaker in qs:
            key, version, _dim, _sc = qinfo[str(qid)]
            if qver != version:
                continue
            fresh[acct].append([str(aid), key, value, importance, dealbreaker])
        rows |= fresh
        if use_cache:
            with contextlib.suppress(redis.RedisError):
                scoring_cache.store(sig, fresh, vers)

    # --- special answers the member allowed into scoring: always from the database, never cached
    special = _consented_special_rows(ids, special_ok, qinfo) if special_ok else {}

    out: dict[uuid.UUID, dict[str, dict[str, Any]]] = {}
    for acct in ids:
        merged = rows.get(acct, [])
        if acct in special:
            merged = sorted(
                [*merged, *special[acct]], key=lambda r: r[0]
            )  # uuid text sorts as uuid
        if not merged:
            continue
        vec: dict[str, dict[str, Any]] = {}
        for _aid, key, value, importance, dealbreaker in merged:
            if key not in by_key:
                continue
            _v, dim, scoring = by_key[key]
            vec[key] = {
                "value": value,
                "importance": importance,
                "dimension": dim,
                "scoring": scoring,
                "is_dealbreaker": dealbreaker,
            }
        if vec:
            out[acct] = vec
    return out


def has_optional_answers(account_id: uuid.UUID) -> bool:
    return Answer.objects.filter(account_id=account_id, question__is_core=False).exists()


def export_for_account(account) -> list[dict[str, object]]:  # type: ignore[no-untyped-def]
    return [
        {
            "question": a.question.key,
            "value": answer_value(a),
            "importance": a.importance,
            "deal_breaker": a.is_dealbreaker,
        }
        for a in Answer.objects.filter(account=account)
        .select_related("question")
        .order_by("question__position")
    ]


def answers_version(account_id: uuid.UUID) -> str:
    """Opaque token that changes whenever `account_id`'s answers change (cache key component)."""
    return scoring_cache.answers_version(account_id)

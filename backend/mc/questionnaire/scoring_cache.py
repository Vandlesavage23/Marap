"""Redis cache of per-account *scoring answer vectors* (perf: docs/perf/discovery-profile.md).

What is cached: for one account, its answers to ACTIVE, NON-SPECIAL questions at the current question
version, as `[answer_id, question_key, value, importance, is_dealbreaker]` rows ordered by answer id.
Special-category answers (encrypted at rest, CLAUDE.md rule 4) are NEVER written here: the selector reads
the few `scoring_allowed` special ones straight from the database on every call.

Keys are opaque (`qa:<question-set signature>:<account uuid>:<version>`), carry a TTL, and hold no phone,
name, email or free text. Invalidation: a per-account version counter (`qa:ver:<account>`) is bumped when
answers are saved or deleted (post_save/post_delete signals, immediately AND again on commit so a reader
that raced the write can't leave a stale entry under the new version) and on account deletion (cascade
delete of Answer rows fires post_delete). A reader fetches the version BEFORE reading the database, so a
slow reader can only ever populate an already-superseded key. Writers never fail because Redis is down.
"""

import json
import logging
import uuid
from collections.abc import Iterable
from typing import Any

import redis
from django.conf import settings

from mc.common.redis import get_redis

logger = logging.getLogger(__name__)

Row = list[Any]  # [answer_id, question_key, value, importance, is_dealbreaker]
VERSION_TTL_SECONDS = 24 * 3600  # must stay > QUESTIONNAIRE_SCORING_CACHE_SECONDS


def _ver_key(account_id: uuid.UUID | str) -> str:
    return f"qa:ver:{account_id}"


def _vec_key(sig: str, account_id: uuid.UUID | str, version: int) -> str:
    return f"qa:{sig}:{account_id}:{version}"


def enabled() -> bool:
    return settings.QUESTIONNAIRE_SCORING_CACHE_SECONDS > 0


def versions(account_ids: list[uuid.UUID]) -> dict[uuid.UUID, int]:
    """Current invalidation version per account (0 = never bumped / expired)."""
    if not account_ids:
        return {}
    raw = get_redis().mget([_ver_key(a) for a in account_ids])
    return {a: int(v or 0) for a, v in zip(account_ids, raw, strict=True)}


def answers_version(account_id: uuid.UUID) -> str:
    """Changes whenever the account's answers change (part of the first-page snapshot key)."""
    return str(versions([account_id])[account_id])


def load(
    sig: str, account_ids: list[uuid.UUID], vers: dict[uuid.UUID, int]
) -> dict[uuid.UUID, list[Row]]:
    """Cached rows for the accounts that have a live entry (an account with no answers caches `[]`)."""
    if not account_ids:
        return {}
    raw = get_redis().mget([_vec_key(sig, a, vers[a]) for a in account_ids])
    return {a: json.loads(v) for a, v in zip(account_ids, raw, strict=True) if v is not None}


def store(sig: str, rows: dict[uuid.UUID, list[Row]], vers: dict[uuid.UUID, int]) -> None:
    if not rows:
        return
    ttl = settings.QUESTIONNAIRE_SCORING_CACHE_SECONDS
    pipe = get_redis().pipeline(transaction=False)
    for account_id, vec in rows.items():
        pipe.set(_vec_key(sig, account_id, vers[account_id]), json.dumps(vec), ex=ttl)
    pipe.execute()


def bump(account_ids: Iterable[uuid.UUID | str]) -> None:
    """Invalidate every cached vector (and first-page snapshot key) for these accounts."""
    ids = list(account_ids)
    if not ids:
        return
    try:
        pipe = get_redis().pipeline(transaction=False)
        for a in ids:
            pipe.incr(_ver_key(a))
            pipe.expire(_ver_key(a), VERSION_TTL_SECONDS)
        pipe.execute()
    except redis.RedisError:  # never fail a write path because the cache is down
        logger.warning("scoring cache bump failed", extra={"accounts": len(ids)})

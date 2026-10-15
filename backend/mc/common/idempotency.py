"""Idempotency for retryable POSTs (Bible §8.1, CLAUDE.md rule 6).

Server stores `(scope, key) → response` in Redis for 24 h; a replay returns the original status and
body. The same key with a different request body is a `conflict`; a concurrent in-flight duplicate is
also a `conflict` (the client retries shortly). This is a *first line* of defence; the database unique
constraint on each create endpoint remains the source of truth.
"""

import hashlib
import json
import re
from collections.abc import Callable
from typing import Any

from django.conf import settings
from rest_framework.response import Response
from rest_framework.views import APIView

from .errors import Conflict, ValidationFailed
from .redis import get_redis

KEY_RE = re.compile(r"^[A-Za-z0-9_\-]{8,64}$")
IN_FLIGHT_TTL = 60


def validate_key(key: str | None, *, required: bool = True) -> str | None:
    if not key:
        if required:
            raise ValidationFailed("Idempotency-Key header is required.")
        return None
    if not KEY_RE.match(key):
        raise ValidationFailed(
            "Idempotency-Key must be 8-64 URL-safe characters (a UUID is ideal)."
        )
    return key


def _fingerprint(payload: Any) -> str:
    return hashlib.sha256(json.dumps(payload, sort_keys=True, default=str).encode()).hexdigest()


def run_idempotent(
    *, scope: str, key: str, payload: Any, fn: Callable[[], tuple[int, Any]]
) -> tuple[int, Any, bool]:
    """Execute `fn` at most once per `(scope, key)`. Returns `(status, body, replayed)`.

    Only successful (<500) outcomes are stored; a failed attempt releases the key so the client
    can retry. `scope` should include the route and account id.
    """
    r = get_redis()
    cache_key = f"idem:{scope}:{key}"
    lock_key = f"{cache_key}:lock"
    fp = _fingerprint(payload)

    stored = r.get(cache_key)
    if stored:
        rec = json.loads(stored)
        if rec["fp"] != fp:
            raise Conflict("This Idempotency-Key was already used with a different request.")
        return rec["status"], rec["body"], True

    if not r.set(lock_key, "1", nx=True, ex=IN_FLIGHT_TTL):
        raise Conflict("A request with this Idempotency-Key is already being processed.")
    try:
        status, body = fn()
        if status < 500:
            r.set(
                cache_key,
                json.dumps({"fp": fp, "status": status, "body": body}, default=str),
                ex=settings.IDEMPOTENCY_TTL_SECONDS,
            )
        return status, body, False
    finally:
        r.delete(lock_key)


class IdempotentMixin(APIView):
    """DRF mixin for POST views marked ⓘ in the endpoint catalogue.

    Subclasses implement `perform_idempotent(request) -> (status, body)` and may set
    `idempotency_required = False` (e.g. endpoints that also accept `client_*_id`).
    """

    idempotency_required = True

    def idempotency_scope(self, request) -> str:  # type: ignore[no-untyped-def]
        user_id = getattr(getattr(request, "user", None), "id", None) or "anon"
        return f"{self.__class__.__name__}:{user_id}"

    def perform_idempotent(self, request) -> tuple[int, Any]:  # type: ignore[no-untyped-def]
        raise NotImplementedError

    def post(self, request, *args, **kwargs):  # type: ignore[no-untyped-def]
        key = validate_key(
            request.headers.get("Idempotency-Key"), required=self.idempotency_required
        )
        if key is None:
            status, body = self.perform_idempotent(request)
            return Response(body, status=status)
        status, body, replayed = run_idempotent(
            scope=self.idempotency_scope(request),
            key=key,
            payload=request.data,
            fn=lambda: self.perform_idempotent(request),
        )
        resp = Response(body, status=status)
        if replayed:
            resp["Idempotent-Replayed"] = "true"
        return resp

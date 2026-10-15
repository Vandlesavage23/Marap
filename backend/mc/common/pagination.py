"""Keyset cursor pagination (Bible §8.1): `?cursor=<opaque>&limit=20` →
`{"items": [...], "next_cursor": "..." | None}`. Stable under concurrent inserts because ordering
is on a unique, time-ordered key (UUIDv7 `id`), never on OFFSET."""

import base64
import json
import uuid
from dataclasses import dataclass
from typing import Any, Generic, TypeVar

from django.db.models import QuerySet

from .errors import ValidationFailed

T = TypeVar("T")
DEFAULT_LIMIT = 20
MAX_LIMIT = 100


@dataclass(frozen=True)
class Page(Generic[T]):
    items: list[T]
    next_cursor: str | None

    def as_dict(self, serialize: Any = lambda x: x) -> dict[str, Any]:
        return {"items": [serialize(i) for i in self.items], "next_cursor": self.next_cursor}


def encode_cursor(last_id: uuid.UUID) -> str:
    raw = json.dumps({"id": str(last_id)}).encode()
    return base64.urlsafe_b64encode(raw).decode().rstrip("=")


def decode_cursor(cursor: str) -> uuid.UUID:
    try:
        padded = cursor + "=" * (-len(cursor) % 4)
        return uuid.UUID(json.loads(base64.urlsafe_b64decode(padded))["id"])
    except Exception as exc:  # malformed cursor from a client
        raise ValidationFailed("Invalid cursor.") from exc


def parse_limit(raw: str | int | None) -> int:
    if raw is None or raw == "":
        return DEFAULT_LIMIT
    try:
        limit = int(raw)
    except (TypeError, ValueError) as exc:
        raise ValidationFailed("limit must be an integer.") from exc
    if limit < 1:
        raise ValidationFailed("limit must be at least 1.")
    return min(limit, MAX_LIMIT)


def paginate(
    queryset: QuerySet[Any],
    *,
    cursor: str | None,
    limit: int = DEFAULT_LIMIT,
    newest_first: bool = True,
) -> Page[Any]:
    """Page over `queryset` ordered by `id` (UUIDv7 = creation order)."""
    limit = max(1, min(limit, MAX_LIMIT))
    if cursor:
        last_id = decode_cursor(cursor)
        queryset = (
            queryset.filter(id__lt=last_id) if newest_first else queryset.filter(id__gt=last_id)
        )
    queryset = queryset.order_by("-id" if newest_first else "id")
    rows = list(queryset[: limit + 1])
    has_more = len(rows) > limit
    rows = rows[:limit]
    return Page(rows, encode_cursor(rows[-1].id) if has_more and rows else None)

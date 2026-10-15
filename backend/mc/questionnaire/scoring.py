"""Pair similarity per question (Bible §10.6 step 2). Pure functions; no DB access.

`similarity(question_scoring, a, b)` ∈ [0, 1] or None if it cannot be computed (then the dimension is
skipped, never counted as zero)."""

from typing import Any


def similarity(scoring: dict[str, Any], a: Any, b: Any) -> float | None:
    if a is None or b is None:
        return None
    kind = scoring.get("kind")
    if kind == "matrix":
        try:
            return float(scoring["matrix"][a][b])
        except (KeyError, TypeError):
            return None
    if kind == "scale":
        lo, hi = scoring["min"], scoring["max"]
        try:
            return max(0.0, 1.0 - abs(float(a) - float(b)) / (hi - lo))
        except (TypeError, ValueError):
            return None
    if kind == "jaccard":
        sa, sb = set(a), set(b)
        if not sa and not sb:
            return None
        return len(sa & sb) / len(sa | sb)
    if kind == "equal":
        return 1.0 if a == b else 0.0
    return None

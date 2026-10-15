"""Compatibility scoring v1 (Bible §10.6 step 2). Pure functions over plain dicts — no DB, no I/O —
so properties (symmetry, skipped dimensions) are testable and forbidden inputs cannot leak in.

Inputs are ONLY questionnaire answers as returned by `questionnaire.selectors.answers_for_scoring`.
FORBIDDEN (CLAUDE.md rule 4, Bible §10.6): photos, likes received, popularity, payment status, free-text
religion, money attitudes, any Phase 5 data. Do not add parameters for them.
"""

from collections import defaultdict
from dataclasses import dataclass
from math import sqrt
from typing import Any

from mc.questionnaire.scoring import similarity

Answers = dict[str, dict[str, Any]]  # question_key -> {value, importance, dimension, scoring, ...}


@dataclass(frozen=True)
class DimensionScore:
    dimension: str
    similarity: float  # s_d in [0, 1]
    weight_a: float  # w_A,d (A's mean importance)
    weight_b: float


@dataclass(frozen=True)
class PairScore:
    score: float  # sqrt(S(A->B) * S(B->A)) in [0, 1]
    dimensions: list[DimensionScore]


def dimension_scores(a: Answers, b: Answers) -> list[DimensionScore]:
    """For each dimension with at least one comparable question on both sides:
    s_d = importance-weighted mean similarity of the pair's answers (weights: A's and B's importance
    averaged per question so s_d itself is symmetric); w_A,d / w_B,d = each side's mean importance."""
    sims: dict[str, list[tuple[float, float]]] = defaultdict(list)  # dim -> [(s_q, q_weight)]
    wa: dict[str, list[int]] = defaultdict(list)
    wb: dict[str, list[int]] = defaultdict(list)
    for key, ans_a in a.items():
        ans_b = b.get(key)
        if ans_b is None:
            continue
        s = similarity(ans_a["scoring"], ans_a["value"], ans_b["value"])
        if s is None:
            continue
        dim = ans_a["dimension"]
        sims[dim].append((s, (ans_a["importance"] + ans_b["importance"]) / 2))
        wa[dim].append(ans_a["importance"])
        wb[dim].append(ans_b["importance"])
    out = []
    for dim, pairs in sims.items():
        total_w = sum(w for _, w in pairs)
        s_d = sum(s * w for s, w in pairs) / total_w
        out.append(
            DimensionScore(dim, s_d, sum(wa[dim]) / len(wa[dim]), sum(wb[dim]) / len(wb[dim]))
        )
    return sorted(out, key=lambda d: d.dimension)


def directional(dims: list[DimensionScore], *, side: str) -> float | None:
    """S(A→B) = Σ w_A,d · s_d / Σ w_A,d (or the B side). Dimensions without data are simply absent."""
    weights = [(d.weight_a if side == "a" else d.weight_b, d.similarity) for d in dims]
    total = sum(w for w, _ in weights)
    if total == 0:
        return None
    return sum(w * s for w, s in weights) / total


def pair_score(a: Answers, b: Answers) -> PairScore | None:
    """Symmetric pair score; None when the two have no comparable dimension."""
    dims = dimension_scores(a, b)
    s_ab, s_ba = directional(dims, side="a"), directional(dims, side="b")
    if s_ab is None or s_ba is None:
        return None
    return PairScore(score=sqrt(s_ab * s_ba), dimensions=dims)


def dealbreaker_ok(owner: Answers, other: Answers, *, min_similarity: float) -> bool:
    """True if every deal-breaker `owner` set is satisfied by `other`'s answer (unanswered → not violated)."""
    for key, ans in owner.items():
        if not ans.get("is_dealbreaker"):
            continue
        theirs = other.get(key)
        if theirs is None:
            continue
        s = similarity(ans["scoring"], ans["value"], theirs["value"])
        if s is not None and s < min_similarity:
            return False
    return True

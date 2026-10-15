"""Explanations come from a fixed template table, never generated text (Bible §10.6 step 4)."""

from .scoring import DimensionScore

WHY = {
    "intent": "Similar plans for when to marry",
    "children": "Aligned on children",
    "faith": "Similar faith practice",
    "marriage_form": "Same view on the kind of marriage",
    "family": "Similar family expectations",
    "roles": "Similar views on household roles",
    "communication": "Compatible communication styles",
    "lifestyle": "Similar lifestyles",
    "location": "Similar plans on where to live",
}
DISCUSS = {
    "intent": "Different timelines for marriage",
    "children": "Different views on children",
    "faith": "Different faith practice",
    "marriage_form": "Different views on the kind of marriage",
    "family": "Different family expectations",
    "roles": "Different views on household roles",
    "communication": "Different communication styles",
    "lifestyle": "Different lifestyles",
    "location": "Different views on where to live",
}
WHY_MIN_SIMILARITY = 0.7  # only claim a strength when the dimension genuinely matches
DISCUSS_MAX_SIMILARITY = 0.5


def explain(viewer_side: list[DimensionScore]) -> tuple[list[str], list[str]]:
    """Top 3 dimensions by w·s → `why`; lowest-scoring dimension with importance ≥ 2 → `discuss`."""
    ranked = sorted(
        (d for d in viewer_side if d.dimension in WHY and d.similarity >= WHY_MIN_SIMILARITY),
        key=lambda d: (-(d.weight_a * d.similarity), d.dimension),
    )
    why = [WHY[d.dimension] for d in ranked[:3]]
    weak = sorted(
        (
            d
            for d in viewer_side
            if d.dimension in DISCUSS and d.weight_a >= 2 and d.similarity <= DISCUSS_MAX_SIMILARITY
        ),
        key=lambda d: (d.similarity, d.dimension),
    )
    discuss = [DISCUSS[weak[0].dimension]] if weak else []
    return why, discuss


def band(score: float, *, strong: float, good: float) -> str:
    return "strong" if score >= strong else "good" if score >= good else "possible"

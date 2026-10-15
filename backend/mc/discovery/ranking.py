"""Re-ranking (Bible §10.6 step 3): exposure caps, new-profile boost, district interleave. Pure functions."""

import uuid
from dataclasses import dataclass
from datetime import datetime, timedelta


@dataclass(frozen=True)
class Scored:
    account_id: uuid.UUID
    profile_id: uuid.UUID
    district: str
    created_at: datetime
    score: float


def apply_exposure_cap(
    items: list[Scored], exposure_today: dict[uuid.UUID, int], *, cap: int
) -> list[Scored]:
    """Drop candidates that already reached the daily impression cap (fairness: nobody is shown to everyone)."""
    return [i for i in items if exposure_today.get(i.account_id, 0) < cap]


def boosted_score(item: Scored, *, now: datetime, boost: float, days: int) -> float:
    return item.score + (boost if now - item.created_at < timedelta(days=days) else 0.0)


def interleave(
    items: list[Scored], scores: dict[uuid.UUID, float], *, run_max: int
) -> list[Scored]:
    """Order by score, but never allow more than `run_max` consecutive candidates from one district
    (when an alternative exists). Deterministic: ties broken by profile id."""
    remaining = sorted(items, key=lambda i: (-scores[i.account_id], str(i.profile_id)))
    out: list[Scored] = []
    while remaining:
        pick = 0
        if len(out) >= run_max and all(o.district == remaining[0].district for o in out[-run_max:]):
            pick = next(
                (n for n, c in enumerate(remaining) if c.district != remaining[0].district), 0
            )
        out.append(remaining.pop(pick))
    return out


def rerank(
    items: list[Scored],
    *,
    exposure_today: dict[uuid.UUID, int],
    now: datetime,
    cap: int,
    boost: float,
    boost_days: int,
    run_max: int,
) -> list[tuple[Scored, float]]:
    kept = apply_exposure_cap(items, exposure_today, cap=cap)
    final = {i.account_id: boosted_score(i, now=now, boost=boost, days=boost_days) for i in kept}
    return [(i, final[i.account_id]) for i in interleave(kept, final, run_max=run_max)]

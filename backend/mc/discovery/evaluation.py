"""Ranking evaluation (MC-060): mutual-interest rate and exposure inequality (Gini) by group."""

from collections import Counter, defaultdict
from datetime import timedelta
from typing import Any

from django.db.models import Count
from django.utils import timezone

from mc.profiles import selectors as profile_selectors

from .models import Impression

AGE_BANDS = [(18, 24), (25, 29), (30, 34), (35, 44), (45, 80)]


def gini(values: list[float]) -> float:
    """Gini coefficient (0 = perfectly equal exposure, →1 = one profile gets everything)."""
    xs = sorted(v for v in values if v >= 0)
    n, total = len(xs), sum(xs)
    if n == 0 or total == 0:
        return 0.0
    return sum((2 * i - n + 1) * x for i, x in enumerate(xs)) / (n * total)


def age_band(age: int) -> str:
    for lo, hi in AGE_BANDS:
        if lo <= age <= hi:
            return f"{lo}-{hi}"
    return "other"


def exposure_gini_by_group(*, days: int = 30) -> dict[str, dict[str, float]]:
    since = timezone.now() - timedelta(days=days)
    counts = {
        r["candidate_id"]: r["n"]
        for r in Impression.objects.filter(shown_at__gte=since)
        .values("candidate_id")
        .annotate(n=Count("id"))
    }
    groups: dict[str, dict[str, list[float]]] = {
        "gender": defaultdict(list),
        "age_band": defaultdict(list),
        "district": defaultdict(list),
    }
    for p in profile_selectors.live_profile_attributes():
        n = float(counts.get(p["account_id"], 0))  # type: ignore[call-overload]
        groups["gender"][str(p["gender"])].append(n)
        groups["age_band"][age_band(int(p["age"]))].append(n)  # type: ignore[call-overload]
        groups["district"][str(p["district"])].append(n)
    return {
        dim: {g: round(gini(v), 4) for g, v in sorted(by.items())} for dim, by in groups.items()
    }


def mutual_interest_rate(*, days: int = 30) -> dict[str, Any]:
    """Of the pairs where anyone acted with `interest`, the share where BOTH sides did."""
    since = timezone.now() - timedelta(days=days)
    directed = set(
        Impression.objects.filter(
            shown_at__gte=since, action=Impression.Action.INTEREST
        ).values_list("viewer_id", "candidate_id")
    )
    pairs = {frozenset(p) for p in directed}
    mutual = sum(1 for p in pairs if all((a, b) in directed for a in p for b in p if a != b))
    shown = Impression.objects.filter(shown_at__gte=since).count()
    return {
        "impressions": shown,
        "interests": len(directed),
        "interest_rate": round(len(directed) / shown, 4) if shown else 0.0,
        "pairs_with_interest": len(pairs),
        "mutual_pairs": mutual,
        "mutual_interest_rate": round(mutual / len(pairs), 4) if pairs else 0.0,
    }


def report(*, days: int = 30) -> dict[str, Any]:
    by_band: Counter[str] = Counter()
    for imp in Impression.objects.filter(
        shown_at__gte=timezone.now() - timedelta(days=days)
    ).values_list("score", flat=True):
        by_band["strong" if imp >= 0.8 else "good" if imp >= 0.65 else "possible"] += 1
    return {
        "window_days": days,
        "mutual_interest": mutual_interest_rate(days=days),
        "exposure_gini": exposure_gini_by_group(days=days),
        "impressions_by_band": dict(by_band),
    }

"""Discovery orchestration (Bible §10.6). Hard filter (profiles.search) → deal-breakers → score →
re-rank → explain → snapshot; pages are served from a signed, 30-minute cursor."""

import json
import uuid
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import TYPE_CHECKING, Any

from django.conf import settings
from django.core import signing
from django.db import transaction
from django.utils import timezone

from mc.common import ratelimit
from mc.common.errors import (
    EntitlementRequired,
    LimitReached,
    NotFound,
    ProfileIncomplete,
    ValidationFailed,
)
from mc.common.redis import get_redis
from mc.common.timeutil import start_of_kampala_day
from mc.entitlements import selectors as entitlement_selectors
from mc.interests import selectors as interest_selectors
from mc.matches import selectors as match_selectors
from mc.profiles import search as profile_search
from mc.profiles import selectors as profile_selectors
from mc.questionnaire import selectors as questionnaire_selectors
from mc.safety import selectors as safety_selectors

from . import explain, ranking, scoring
from .models import Impression, ModelVersion

if TYPE_CHECKING:
    from mc.accounts.models import Account

SALT = "discovery.cursor"


@dataclass(frozen=True)
class RankedEntry:
    profile_id: str
    account_id: str
    score: float
    why: list[str]
    discuss: list[str]


def exposure_today(candidate_ids: list[uuid.UUID], now: datetime) -> dict[uuid.UUID, int]:
    from django.db.models import Count

    rows = (
        Impression.objects.filter(
            candidate_id__in=candidate_ids, shown_at__gte=start_of_kampala_day(now)
        )
        .values("candidate_id")
        .annotate(n=Count("id"))
    )
    return {r["candidate_id"]: r["n"] for r in rows}


def _exclusions(viewer_id: uuid.UUID, now: datetime, *, include_recent: bool) -> set[uuid.UUID]:
    excluded = safety_selectors.blocked_either_way_ids(
        viewer_id
    ) | interest_selectors.pending_counterpart_ids(viewer_id)
    excluded |= match_selectors.counterpart_ids(
        viewer_id, ended_since=now - timedelta(days=settings.INTEREST_RESEND_COOLDOWN_DAYS)
    )  # matched now, or unmatched recently
    excluded |= set(
        Impression.objects.filter(
            viewer_id=viewer_id, action=Impression.Action.NOT_RELEVANT
        ).values_list("candidate_id", flat=True)
    )
    if include_recent:
        since = now - timedelta(days=settings.REPEAT_HIDE_DAYS)
        excluded |= set(
            Impression.objects.filter(viewer_id=viewer_id, shown_at__gte=since).values_list(
                "candidate_id", flat=True
            )
        )
    return excluded


def active_model() -> ModelVersion:
    return ModelVersion.objects.filter(active=True).order_by("-created_at").first() or ModelVersion(
        name="v1-weighted"
    )


def build_ranked_pool(
    viewer: "Account", *, now: datetime | None = None
) -> tuple[list[RankedEntry], str]:
    now = now or timezone.now()
    ctx = profile_selectors.viewer_context_for(viewer)
    if ctx is None:
        raise ProfileIncomplete("Finish your profile to start discovering matches.")
    rows = profile_search.hard_filter_candidates(
        ctx,
        exclude_account_ids=_exclusions(viewer.id, now, include_recent=True),
        limit=settings.DISCOVERY_POOL_SIZE,
    )
    if (
        not rows
    ):  # pool exhausted → allow candidates seen recently (never blocked / not_relevant ones)
        rows = profile_search.hard_filter_candidates(
            ctx,
            exclude_account_ids=_exclusions(viewer.id, now, include_recent=False),
            limit=settings.DISCOVERY_POOL_SIZE,
        )
    ids = [r["account_id"] for r in rows]
    answers = questionnaire_selectors.answers_for_scoring([viewer.id, *ids])
    mine = answers.get(viewer.id, {})

    scored: list[ranking.Scored] = []
    explanations: dict[uuid.UUID, tuple[list[str], list[str]]] = {}
    for r in rows:
        theirs = answers.get(r["account_id"], {})
        thr = settings.DEALBREAKER_MIN_SIMILARITY
        if not (
            scoring.dealbreaker_ok(mine, theirs, min_similarity=thr)
            and scoring.dealbreaker_ok(theirs, mine, min_similarity=thr)
        ):
            continue
        pair = scoring.pair_score(mine, theirs)
        scored.append(
            ranking.Scored(
                r["account_id"],
                r["id"],
                r["district"],
                r["created_at"],
                pair.score if pair else 0.0,
            )
        )
        explanations[r["account_id"]] = explain.explain(pair.dimensions) if pair else ([], [])

    ordered = ranking.rerank(
        scored,
        exposure_today=exposure_today([s.account_id for s in scored], now),
        now=now,
        cap=settings.EXPOSURE_DAILY_CAP,
        boost=settings.NEW_PROFILE_BOOST,
        boost_days=settings.NEW_PROFILE_BOOST_DAYS,
        run_max=settings.DISTRICT_RUN_MAX,
    )
    entries = [
        RankedEntry(
            str(s.profile_id), str(s.account_id), round(final, 4), *explanations[s.account_id]
        )
        for s, final in ordered
    ]
    return entries, active_model().name


def _store_snapshot(viewer_id: uuid.UUID, entries: list[RankedEntry], model: str) -> str:
    token = uuid.uuid4().hex
    payload = json.dumps(
        {"viewer": str(viewer_id), "model": model, "entries": [e.__dict__ for e in entries]}
    )
    get_redis().set(f"disc:{token}", payload, ex=settings.DISCOVERY_CURSOR_TTL_SECONDS)
    return token


def _make_cursor(viewer_id: uuid.UUID, token: str, offset: int) -> str:
    return signing.dumps({"t": token, "o": offset, "v": str(viewer_id)}, salt=SALT, compress=False)


def _read_cursor(viewer_id: uuid.UUID, cursor: str) -> tuple[list[dict[str, Any]], str, int, str]:
    try:
        data = signing.loads(cursor, salt=SALT, max_age=settings.DISCOVERY_CURSOR_TTL_SECONDS)
    except signing.SignatureExpired as exc:
        raise ValidationFailed(
            "This page has expired. Refresh to see new matches.", cursor_expired=True
        ) from exc
    except signing.BadSignature as exc:
        raise ValidationFailed("Invalid cursor.") from exc
    if data.get("v") != str(viewer_id):
        raise ValidationFailed("Invalid cursor.")
    raw = get_redis().get(f"disc:{data['t']}")
    if raw is None:
        raise ValidationFailed(
            "This page has expired. Refresh to see new matches.", cursor_expired=True
        )
    snap = json.loads(raw)
    return snap["entries"], snap["model"], int(data["o"]), data["t"]


def next_candidates(
    viewer: "Account", *, cursor: str | None, limit: int | None = None
) -> dict[str, Any]:
    """One page of CandidateCards + `next_cursor`. Enforces capability `browse`, rate and daily-view limits."""
    now = timezone.now()
    limit = max(1, min(limit or settings.DISCOVERY_PAGE_SIZE, 50))
    if not entitlement_selectors.has_capability(viewer, "browse", now):
        raise EntitlementRequired(
            "Browsing needs an active trial or membership.", capability="browse"
        )
    ratelimit.hit(
        f"discovery:{viewer.id}", limit=settings.DISCOVERY_REQUESTS_PER_HOUR, window_seconds=3600
    )
    if (
        Impression.objects.filter(viewer=viewer, shown_at__gte=start_of_kampala_day(now)).count()
        >= settings.DISCOVERY_DAILY_VIEWS_LIMIT
    ):
        raise LimitReached(
            "You've seen plenty of profiles today. Come back tomorrow.", retry_after=3600
        )

    if cursor:
        raw_entries, model, offset, token = _read_cursor(viewer.id, cursor)
    else:
        entries, model = build_ranked_pool(viewer, now=now)
        raw_entries = [e.__dict__ for e in entries]
        token, offset = _store_snapshot(viewer.id, entries, model), 0

    window = raw_entries[offset : offset + limit]
    gone = safety_selectors.blocked_either_way_ids(
        viewer.id
    ) | interest_selectors.pending_counterpart_ids(viewer.id)
    window = [e for e in window if uuid.UUID(e["account_id"]) not in gone]  # re-check at serve time
    cards = profile_selectors.card_data([uuid.UUID(e["profile_id"]) for e in window], viewer)

    items: list[dict[str, Any]] = []
    impressions = []
    for n, e in enumerate(window):
        card = cards.get(uuid.UUID(e["profile_id"]))
        if card is None:
            continue  # went offline since the snapshot
        items.append(
            {
                **card,
                "why": e["why"],
                "discuss": e["discuss"],
                "score_band": explain.band(
                    e["score"], strong=settings.SCORE_BAND_STRONG, good=settings.SCORE_BAND_GOOD
                ),
            }
        )
        impressions.append(
            Impression(
                viewer=viewer,
                candidate_id=e["account_id"],
                score=min(e["score"], 9.9999),
                model_version=model,
                position=min(offset + n, 32000),
                shown_at=now,
            )
        )
    with transaction.atomic():
        Impression.objects.bulk_create(impressions)
    next_offset = offset + limit
    return {
        "items": items,
        "next_cursor": _make_cursor(viewer.id, token, next_offset)
        if next_offset < len(raw_entries)
        else None,
    }


def record_feedback(*, viewer: "Account", profile_id: uuid.UUID, action: str) -> None:
    """`pass` / `not_relevant` on a profile the viewer has been shown. `not_relevant` hides it forever."""
    if action not in (Impression.Action.PASS, Impression.Action.NOT_RELEVANT):
        raise ValidationFailed("Unknown action.")
    account_id = profile_selectors.account_id_for_profile(profile_id)
    imp = (
        Impression.objects.filter(viewer=viewer, candidate_id=account_id)
        .order_by("-shown_at", "-id")
        .first()
        if account_id
        else None
    )
    if imp is None:
        raise NotFound()
    imp.action = action
    imp.save(update_fields=["action", "updated_at"])


def record_interest_action(*, viewer_id: uuid.UUID, candidate_id: uuid.UUID) -> None:
    """Called by interests after an interest is sent: marks the latest impression."""
    imp = (
        Impression.objects.filter(viewer_id=viewer_id, candidate_id=candidate_id)
        .order_by("-shown_at", "-id")
        .first()
    )
    if imp:
        imp.action = Impression.Action.INTEREST
        imp.save(update_fields=["action", "updated_at"])


def are_mutually_eligible(a: "Account", b: "Account") -> bool:
    """Both live profiles pass each other's hard filters (age ranges, married opt-in, diaspora, children,
    distance) and neither violates the other's deal-breakers. Blocks/pending interests are checked by callers."""
    ctx_a, ctx_b = profile_selectors.viewer_context_for(a), profile_selectors.viewer_context_for(b)
    if ctx_a is None or ctx_b is None:
        return False
    if not profile_search.candidate_queryset(ctx_a).filter(account_id=b.id).exists():
        return False
    if not profile_search.candidate_queryset(ctx_b).filter(account_id=a.id).exists():
        return False
    answers = questionnaire_selectors.answers_for_scoring([a.id, b.id])
    mine, theirs = answers.get(a.id, {}), answers.get(b.id, {})
    thr = settings.DEALBREAKER_MIN_SIMILARITY
    return scoring.dealbreaker_ok(mine, theirs, min_similarity=thr) and scoring.dealbreaker_ok(
        theirs, mine, min_similarity=thr
    )


def purge_impressions(*, before) -> int:  # type: ignore[no-untyped-def]
    """Retention: impressions older than `before` (180 days). `not_relevant` feedback older than that is kept
    as a tombstone so a hidden profile never reappears."""
    qs = Impression.objects.filter(shown_at__lt=before).exclude(
        action=Impression.Action.NOT_RELEVANT
    )
    deleted, _ = qs.delete()
    return deleted

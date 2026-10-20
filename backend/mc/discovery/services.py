"""Discovery orchestration (Bible §10.6). Hard filter (profiles.search) → deal-breakers → score →
re-rank → explain → snapshot; pages are served from a signed, 30-minute cursor."""

import hashlib
import json
import uuid
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import TYPE_CHECKING, Any

from django.conf import settings
from django.core import signing
from django.db import transaction
from django.utils import timezone

from mc.accounts import services as account_services
from mc.common import quota, ratelimit
from mc.common.errors import (
    LimitReached,
    NotFound,
    ProfileIncomplete,
    ValidationFailed,
)
from mc.common.redis import get_redis
from mc.common.timeutil import iso_z, next_kampala_midnight, start_of_kampala_day
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
_ABOUT_YOU = "Tell us a little about you (your first name, birth date and whether you are a man or a woman) to see members."


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


@dataclass(frozen=True)
class PoolEntry:
    """A hard-filtered, deal-breaker-checked, scored candidate, BEFORE exposure caps / boost / interleave."""

    account_id: uuid.UUID
    profile_id: uuid.UUID
    district: str
    created_at: datetime
    score: float
    why: list[str]
    discuss: list[str]


def _score_pool(viewer: "Account", ctx: Any, *, now: datetime) -> list[PoolEntry]:
    """Steps 1-2 of §10.6: hard filter (capped at DISCOVERY_POOL_SIZE rows, most recently seen first),
    deal-breakers both ways, compatibility score + explanation."""
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

    pool: list[PoolEntry] = []
    for r in rows:
        theirs = answers.get(r["account_id"], {})
        thr = settings.DEALBREAKER_MIN_SIMILARITY
        if not (
            scoring.dealbreaker_ok(mine, theirs, min_similarity=thr)
            and scoring.dealbreaker_ok(theirs, mine, min_similarity=thr)
        ):
            continue
        pair = scoring.pair_score(mine, theirs)
        why, discuss = explain.explain(pair.dimensions) if pair else ([], [])
        pool.append(
            PoolEntry(
                r["account_id"],
                r["id"],
                r["district"],
                r["created_at"],
                pair.score if pair else 0.0,
                why,
                discuss,
            )
        )
    return pool


def _rank_pool(pool: list[PoolEntry], *, now: datetime) -> list[RankedEntry]:
    """Steps 3-4: exposure cap (fresh per call), new-profile boost, district interleave."""
    scored = [
        ranking.Scored(e.account_id, e.profile_id, e.district, e.created_at, e.score) for e in pool
    ]
    explanations = {e.account_id: (e.why, e.discuss) for e in pool}
    ordered = ranking.rerank(
        scored,
        exposure_today=exposure_today([s.account_id for s in scored], now),
        now=now,
        cap=settings.EXPOSURE_DAILY_CAP,
        boost=settings.NEW_PROFILE_BOOST,
        boost_days=settings.NEW_PROFILE_BOOST_DAYS,
        run_max=settings.DISTRICT_RUN_MAX,
    )
    return [
        RankedEntry(
            str(s.profile_id), str(s.account_id), round(final, 4), *explanations[s.account_id]
        )
        for s, final in ordered
    ]


def build_ranked_pool(
    viewer: "Account", *, now: datetime | None = None
) -> tuple[list[RankedEntry], str]:
    """Full rebuild (no reuse): the reference behaviour that the cached first page must reproduce."""
    now = now or timezone.now()
    ctx = profile_selectors.browse_context_for(viewer)
    if ctx is None:
        raise ProfileIncomplete(_ABOUT_YOU, missing=["birth_date", "gender"])
    return _rank_pool(_score_pool(viewer, ctx, now=now), now=now), active_model().name


# ---- first-page scored-pool reuse -------------------------------------------------------------------
# Same member re-opening discovery within DISCOVERY_SNAPSHOT_REUSE_SECONDS reuses the *scored* pool (the
# expensive part: answers + pair scores) but everything member-visible and safety-relevant is recomputed:
# blocks / pending interests / matches / not_relevant / recent impressions are re-applied from the database,
# and exposure caps + boost + interleave re-run. The key embeds the viewer's search context and answers
# version, so editing profile, preferences or answers can never see a stale pool.
def _pool_key(viewer_id: uuid.UUID, ctx: Any) -> str:
    fingerprint = repr(
        (
            ctx,
            questionnaire_selectors.answers_version(viewer_id),
            settings.DISCOVERY_POOL_SIZE,
            settings.DEALBREAKER_MIN_SIMILARITY,
            settings.MARRIED_PROFILES_ENABLED,
        )
    )
    digest = hashlib.sha1(fingerprint.encode(), usedforsecurity=False).hexdigest()[:20]
    return f"disc:pool:{viewer_id}:{digest}"


def _load_pool(key: str) -> tuple[list[PoolEntry], str] | None:
    raw = get_redis().get(key)
    if raw is None:
        return None
    data = json.loads(raw)
    return [
        PoolEntry(
            uuid.UUID(e[0]), uuid.UUID(e[1]), e[2], datetime.fromisoformat(e[3]), e[4], e[5], e[6]
        )
        for e in data["pool"]
    ], data["model"]


def _save_pool(key: str, pool: list[PoolEntry], model: str) -> None:
    payload = json.dumps(
        {
            "model": model,
            "pool": [
                [str(e.account_id), str(e.profile_id), e.district, e.created_at.isoformat(),
                 e.score, e.why, e.discuss]
                for e in pool
            ],
        }
    )  # fmt: skip
    get_redis().set(key, payload, ex=settings.DISCOVERY_SNAPSHOT_REUSE_SECONDS)


def first_page_pool(viewer: "Account", *, now: datetime) -> tuple[list[RankedEntry], str]:
    ctx = profile_selectors.browse_context_for(viewer)
    if ctx is None:
        raise ProfileIncomplete(_ABOUT_YOU, missing=["birth_date", "gender"])
    ttl = settings.DISCOVERY_SNAPSHOT_REUSE_SECONDS
    key = _pool_key(viewer.id, ctx) if ttl > 0 else ""
    if key and (cached := _load_pool(key)) is not None:
        pool, model = cached
        excluded = _exclusions(viewer.id, now, include_recent=True)
        pool = [e for e in pool if e.account_id not in excluded]
        if pool:
            return _rank_pool(pool, now=now), model
    pool = _score_pool(viewer, ctx, now=now)
    model = active_model().name
    if key:
        _save_pool(key, pool, model)
    return _rank_pool(pool, now=now), model


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


def _browse_quota(
    summary: "entitlement_selectors.EntitlementState", viewer: "Account", now: datetime
) -> tuple[int | None, str]:
    limit = entitlement_selectors.browse_card_limit(summary)
    return limit, quota.day_key("cards", viewer.id, now)


def browse_usage(
    viewer: "Account", summary: "entitlement_selectors.EntitlementState", now: datetime
) -> dict[str, Any]:
    """`{limit, used, resets_at}` for today's card allowance (limit None = no daily cap)."""
    limit, key = _browse_quota(summary, viewer, now)
    return {
        "limit": limit,
        "used": quota.used(key),
        "resets_at": next_kampala_midnight(now),
    }


def next_candidates(
    viewer: "Account",
    *,
    cursor: str | None,
    limit: int | None = None,
    ip: str | None = None,
    install_id: str | None = None,
) -> dict[str, Any]:
    """One page of CandidateCards + `next_cursor`. Any signed-in member may browse (capability `browse`); a member
    who has not verified their identity gets LIMITED cards. Enforces the rate limit, the daily card allowance
    (unverified 30, verified free 60, trial/member none: 429 `limit_reached` with `resets_at`) and, for unverified
    viewers, the per-IP and per-device caps."""
    now = timezone.now()
    limit = max(1, min(limit or settings.DISCOVERY_PAGE_SIZE, 50))
    summary = entitlement_selectors.entitlement_summary(viewer, now)
    if not summary.capabilities[
        "browse"
    ]:  # pragma: no cover - browse is granted to every signed-in member
        raise LimitReached("Browsing isn't available right now.")
    if not summary.verified:
        account_services.require_verification_consents(viewer)
        ratelimit.hit_client(
            "browse",
            ip=ip,
            install_id=install_id,
            limit=settings.BROWSE_PAGES_PER_IP_PER_DAY_UNVERIFIED,
            window_seconds=24 * 3600,
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
    card_limit, card_key = _browse_quota(summary, viewer, now)
    if card_limit is not None and quota.used(card_key) >= card_limit:
        raise _cards_exhausted(card_limit, now)

    if cursor:
        raw_entries, model, offset, token = _read_cursor(viewer.id, cursor)
    else:
        entries, model = first_page_pool(viewer, now=now)
        raw_entries = [e.__dict__ for e in entries]
        token, offset = _store_snapshot(viewer.id, entries, model), 0

    window = raw_entries[offset : offset + limit]
    if (
        cursor
    ):  # a page-1 pool was filtered against blocks/pending milliseconds ago; later pages re-check
        gone = safety_selectors.blocked_either_way_ids(
            viewer.id
        ) | interest_selectors.pending_counterpart_ids(viewer.id)
        window = [e for e in window if uuid.UUID(e["account_id"]) not in gone]
    cards = profile_selectors.card_data([uuid.UUID(e["profile_id"]) for e in window], viewer)

    shown: list[tuple[int, dict[str, Any], dict[str, Any]]] = []
    for n, e in enumerate(window):
        card = cards.get(uuid.UUID(e["profile_id"]))
        if card is None:
            continue  # went offline since the snapshot
        shown.append((n, e, card))
    truncated = False
    if card_limit is not None:
        granted = quota.consume_upto(card_key, want=len(shown), limit=card_limit, now=now)
        if granted == 0 and shown:
            raise _cards_exhausted(card_limit, now)
        truncated = granted < len(shown)
        shown = shown[:granted]

    items: list[dict[str, Any]] = []
    impressions = []
    for n, e, card in shown:
        if card["limited"]:
            items.append(card)  # nothing about compatibility is disclosed to an unverified viewer
        else:
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
    usage = browse_usage(viewer, summary, now)
    return {
        "items": items,
        "next_cursor": _make_cursor(viewer.id, token, next_offset)
        if next_offset < len(raw_entries) and not truncated
        else None,
        "browse": {**usage, "resets_at": iso_z(usage["resets_at"])},
    }


def _cards_exhausted(card_limit: int, now: datetime) -> LimitReached:
    resets = next_kampala_midnight(now)
    return LimitReached(
        "You've seen today's profiles. New ones are waiting tomorrow.",
        resets_at=iso_z(resets),
        limit=card_limit,
        retry_after=max(int((resets - now).total_seconds()), 1),
    )


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


GUEST_MAX_CARDS = 40


def guest_feed(
    *, seeking: str, cursor: str | None, limit: int, ip: str | None, install_id: str | None
) -> dict[str, Any]:
    """Public, signed-out browsing (ADR-0009 amendment: look first, sign in later). LIMITED cards only — primary
    photo (never a `verified_only` one), first name, age, district, intention — newest live profiles of the gender
    being sought, at most `GUEST_MAX_CARDS` per person. Per-IP and per-device capped like unverified browsing."""
    from mc.media import selectors as media_selectors
    from mc.profiles.models import Photo, Profile
    from mc.profiles.policies import photo_visible_to

    ratelimit.hit_client(
        "guest_browse",
        ip=ip,
        install_id=install_id,
        limit=settings.BROWSE_PAGES_PER_IP_PER_DAY_UNVERIFIED,
        window_seconds=24 * 3600,
    )
    try:
        offset = max(0, int(cursor or 0))
    except ValueError:
        offset = 0
    limit = max(1, min(limit, 20, GUEST_MAX_CARDS - offset)) if offset < GUEST_MAX_CARDS else 0
    profiles = list(
        Profile.objects.filter(
            status=Profile.Status.LIVE, account__status="active", gender=seeking
        ).order_by("-created_at", "id")[offset : offset + limit]
    )
    photos: dict[uuid.UUID, Photo] = {}
    for ph in (
        Photo.objects.filter(profile_id__in=[p.id for p in profiles], moderation_status="approved")
        .select_related("media")
        .order_by("profile_id", "position")
    ):
        photos.setdefault(ph.profile_id, ph)
    items = []
    for p in profiles:
        first = photos.get(p.id)
        shown = []
        if first and photo_visible_to(viewer_verified=False, target=p, is_primary=True):
            url = media_selectors.signed_url_prechecked(first.media)
            if url:
                shown.append({"url": url, "w": first.media.width, "h": first.media.height})
        items.append(
            {
                "profile_id": str(p.id),
                "display_name": p.display_name,
                "age": profile_selectors.age_of(p),
                "district": p.district,
                "photos": shown,
                "intention": p.intention,
                "badges": profile_selectors.badges(first is not None),
                "limited": True,
            }
        )
    more = offset + len(profiles) < GUEST_MAX_CARDS and len(profiles) == limit and limit > 0
    return {
        "items": items,
        "next_cursor": str(offset + limit) if more else None,
        "sign_in_to_see_more": not more,
    }

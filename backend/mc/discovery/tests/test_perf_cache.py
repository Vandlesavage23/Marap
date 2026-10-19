"""Discovery performance guards (docs/perf/discovery-profile.md): bounded SQL per page, cache invalidation,
and "the fast path is the same ranking as the reference rebuild"."""

import random
from datetime import UTC, datetime

import pytest
from django.db import connection
from django.test.utils import CaptureQueriesContext
from django.utils import timezone

from devtools.factories import create_member, default_answer_values, save_answers
from mc.common.redis import get_redis
from mc.discovery import services
from mc.discovery.tests.test_api import discover, member_client
from mc.entitlements import services as ent
from mc.profiles import selectors as profile_selectors
from mc.questionnaire import selectors as q_selectors
from mc.questionnaire import services as q_services
from mc.questionnaire.models import Question
from mc.safety import services as safety_services

pytestmark = pytest.mark.django_db

# Measured: cold page 28 queries, warm page 23 (was 183 for the same 20-card page with 2 photos each).
COLD_PAGE_MAX_QUERIES = 34
WARM_PAGE_MAX_QUERIES = 28
CARD_DATA_MAX_QUERIES = 4  # profiles + photos (+ blocks/gender when photos exist) — never per card


def opposite_values(base: dict) -> dict:
    """Answers as different as possible from `base` (so the pair score is clearly lower)."""
    out = {}
    for q in Question.objects.filter(key__in=list(base)):
        v = base[q.key]
        if q.type == "single":
            out[q.key] = next(o["value"] for o in q.options if o["value"] != v)
        elif q.type == "multi":
            out[q.key] = [next(o["value"] for o in q.options if o["value"] not in v)]
        else:
            lo, hi = q.options["min"], q.options["max"]
            out[q.key] = lo if abs(v - lo) > abs(v - hi) else hi
    return out


def pool_ids(viewer) -> list[str]:
    entries, _ = services.first_page_pool(viewer, now=timezone.now())
    return [e.account_id for e in entries]


def _viewer_and_two(viewer_values=None):
    base = default_answer_values()
    me = create_member(gender="male", age=30, answer_values=viewer_values or base)
    ent.start_trial(account=me)
    same = create_member(gender="female", age=28, answer_values=base)
    diff = create_member(gender="female", age=28, answer_values=opposite_values(base))
    return base, me, same, diff


# ------------------------------------------------------------------ bounded SQL per page
def test_discovery_page_sql_is_bounded_cold_and_warm():
    c, r, me = member_client(gender="male", age=30)
    ent.start_trial(account=me)
    for _ in range(30):
        create_member(gender="female", age=28, photos=2)
    with CaptureQueriesContext(connection) as cold:
        resp = discover(c, r, limit=20)
    assert resp.status_code == 200 and len(resp.json()["items"]) == 20
    assert all(len(i["photos"]) == 2 and i["photos"][0]["url"] for i in resp.json()["items"])
    assert len(cold) <= COLD_PAGE_MAX_QUERIES, [q["sql"][:80] for q in cold.captured_queries]
    with CaptureQueriesContext(
        connection
    ) as warm:  # same viewer, scored pool reused, 10 more cards
        resp = discover(c, r, limit=20)
    assert resp.status_code == 200 and len(resp.json()["items"]) == 10
    assert len(warm) <= WARM_PAGE_MAX_QUERIES, [q["sql"][:80] for q in warm.captured_queries]


def test_card_data_query_count_does_not_grow_with_cards():
    _, me, *_ = _viewer_and_two()
    for _ in range(18):
        create_member(gender="female", age=28, photos=3)
    from mc.profiles.models import Profile

    ids = list(
        Profile.objects.filter(account__profile__gender="female").values_list("id", flat=True)
    )
    counts = []
    for n in (1, len(ids)):
        with CaptureQueriesContext(connection) as ctx:
            cards = profile_selectors.card_data(ids[:n], me)
        assert len(cards) == n
        counts.append(len(ctx))
    assert counts[1] <= CARD_DATA_MAX_QUERIES + 3 and counts[1] - counts[0] <= 1, counts


def test_card_photos_still_follow_the_media_policy():
    """The batched check must deny exactly what the per-media policy denied."""
    _, me, same, _diff = _viewer_and_two()
    from mc.profiles.models import Profile

    pid = Profile.objects.get(account=same).id
    assert profile_selectors.card_data([pid], me)[pid]["photos"][0]["url"]
    safety_services.block(blocker=me, blocked_id=same.id)
    assert profile_selectors.card_data([pid], me)[pid]["photos"][0]["url"] is None
    safety_services.unblock(blocker=me, profile_id=pid)
    assert profile_selectors.card_data([pid], me)[pid]["photos"][0]["url"]
    # v2: a verified member without a trial can browse and see photos; the opposite-gender rule still holds.
    free = create_member(gender="male", age=30)
    assert profile_selectors.card_data([pid], free)[pid]["photos"][0]["url"]
    same_gender = create_member(gender="female", age=30)
    assert profile_selectors.card_data([pid], same_gender)[pid]["photos"][0]["url"] is None


# ------------------------------------------------------------------ same ranking as a full rebuild
def test_cached_first_page_pool_is_identical_to_a_full_rebuild():
    base = default_answer_values()
    me = create_member(gender="male", age=30, answer_values=base, dealbreakers=("children_want",))
    ent.start_trial(account=me)
    rng = random.Random(7)
    for i in range(14):
        vals = dict(base) if i % 3 == 0 else opposite_values(base)
        if i % 2:
            vals = {
                **default_answer_values(rng),
                **{k: v for k, v in vals.items() if k != "alcohol"},
            }
        create_member(gender="female", age=24 + i % 9, district=("Kampala", "Wakiso", "Jinja")[i % 3],
                      answer_values=vals, dealbreakers=("smoking",) if i % 4 == 0 else ())  # fmt: skip
    now = datetime(2026, 10, 16, 12, 0, tzinfo=UTC)
    reference, model = services.build_ranked_pool(me, now=now)
    assert reference
    for _ in range(2):  # 1st: cold caches, 2nd: answer-vector cache + pool snapshot both warm
        got, got_model = services.first_page_pool(me, now=now)
        assert [e.__dict__ for e in got] == [e.__dict__ for e in reference]
        assert got_model == model
    assert get_redis().keys("disc:pool:*") and get_redis().keys("qa:*")


# ------------------------------------------------------------------ invalidation
def test_answers_change_reorders_ranking_even_with_warm_caches():
    base, me, same, diff = _viewer_and_two()
    assert pool_ids(me) == [str(same.id), str(diff.id)]
    assert pool_ids(me) == [str(same.id), str(diff.id)]  # warm: from the snapshot
    q_services.save_answers(
        account=me,
        answers=[{"question": k, "value": v} for k, v in opposite_values(base).items()],
    )
    assert pool_ids(me) == [str(diff.id), str(same.id)]  # viewer answers changed → no stale pool


def test_candidate_answers_change_is_seen_by_the_vector_cache_immediately():
    base, me, same, diff = _viewer_and_two()
    before = q_selectors.answers_for_scoring([same.id])[same.id]
    assert q_selectors.answers_for_scoring([same.id])[same.id] == before  # warm hit
    key, other = next((k, v) for k, v in opposite_values(base).items())
    q_services.save_answers(account=same, answers=[{"question": key, "value": other}])
    after = q_selectors.answers_for_scoring([same.id])[same.id]
    assert after[key]["value"] == other and before[key]["value"] == base[key]
    save_answers(same, {key: base[key]})  # factory (bulk_create) path invalidates too
    assert q_selectors.answers_for_scoring([same.id])[same.id][key]["value"] == base[key]


def test_block_removes_candidate_immediately_with_warm_pool_cache():
    _base, me, same, diff = _viewer_and_two()
    assert set(pool_ids(me)) == {str(same.id), str(diff.id)}
    assert get_redis().keys("disc:pool:*")  # warm
    safety_services.block(blocker=me, blocked_id=same.id)
    assert pool_ids(me) == [str(diff.id)]
    assert get_redis().keys("disc:pool:*")  # still warm: the block was applied on top of it
    safety_services.block(blocker=diff, blocked_id=me.id)  # blocked BY the candidate
    entries, _ = services.first_page_pool(me, now=timezone.now())
    assert entries == [] or all(e.account_id not in (str(same.id), str(diff.id)) for e in entries)


def test_block_hides_card_on_the_api_with_warm_cache():
    c, r, me = member_client(gender="male", age=30)
    ent.start_trial(account=me)
    women = [create_member(gender="female", age=28) for _ in range(3)]
    first = discover(c, r, limit=1).json()  # warms the pool snapshot
    assert len(first["items"]) == 1
    for w in women:
        safety_services.block(blocker=me, blocked_id=w.id)
    again = discover(c, r, limit=5).json()
    assert again["items"] == []


def test_preference_change_is_not_served_from_a_stale_pool():
    from mc.profiles import preferences

    _base, me, same, diff = _viewer_and_two()
    assert len(pool_ids(me)) == 2
    preferences.set_preferences(account=me, data={"age_min": 40, "age_max": 50})
    assert pool_ids(me) == []  # both women are 28


def test_account_deletion_clears_scoring_vectors():
    _base, me, same, _diff = _viewer_and_two()
    assert q_selectors.answers_for_scoring([same.id])
    v_before = q_selectors.answers_version(same.id)
    same_id = same.id
    same.delete()  # cascades Answer rows
    assert q_selectors.answers_version(same_id) != v_before
    assert q_selectors.answers_for_scoring([same_id]) == {}


def test_special_answers_are_never_written_to_the_cache():
    base = default_answer_values()
    me = create_member(gender="male", age=30, answer_values=base)
    other = create_member(
        gender="female",
        age=28,
        answer_values={**base, "faith_practice": "weekly", "money_attitude": "joint"},
    )
    for _ in range(2):
        got = q_selectors.answers_for_scoring([me.id, other.id])[other.id]
        assert got["faith_practice"]["value"] == "weekly" and "money_attitude" not in got
    redis = get_redis()
    blob = b"".join(redis.get(k) or b"" for k in redis.scan_iter("qa:*") if b"ver" not in k)
    assert blob  # something was cached ...
    assert b"faith_practice" not in blob and b"weekly" not in blob and b"money_attitude" not in blob
    assert b"joint" not in blob  # ... but no special-category data

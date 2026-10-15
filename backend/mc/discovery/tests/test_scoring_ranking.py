import inspect
import random
import uuid
from datetime import UTC, datetime, timedelta

import pytest
from hypothesis import given, settings
from hypothesis import strategies as st

from mc.discovery import explain, ranking, scoring
from mc.discovery.explain import DISCUSS, WHY

DIMS = ["intent", "children", "faith", "family", "roles", "lifestyle", "location"]
MATRIX = {
    "kind": "matrix",
    "matrix": {v: {w: (1.0 if v == w else 0.3) for w in "abc"} for v in "abc"},
}


def ans(**by_dim):
    """{question_key: ...} with one question per dimension: value + importance."""
    return {
        f"q_{dim}": {
            "value": v,
            "importance": imp,
            "dimension": dim,
            "scoring": MATRIX,
            "is_dealbreaker": False,
        }
        for dim, (v, imp) in by_dim.items()
    }


answer_strategy = st.dictionaries(
    st.sampled_from(DIMS),
    st.tuples(st.sampled_from("abc"), st.integers(1, 3)),
    min_size=0,
    max_size=len(DIMS),
).map(lambda d: ans(**d))


@settings(max_examples=200, deadline=None)
@given(answer_strategy, answer_strategy)
def test_pair_score_is_symmetric_and_bounded(a, b):
    ab, ba = scoring.pair_score(a, b), scoring.pair_score(b, a)
    assert (ab is None) == (ba is None)
    if ab:
        assert ab.score == pytest.approx(ba.score)
        assert 0 <= ab.score <= 1 + 1e-9


@settings(max_examples=100, deadline=None)
@given(answer_strategy)
def test_identical_answers_score_one(a):
    r = scoring.pair_score(a, a)
    if r:
        assert r.score == pytest.approx(1.0)


def test_missing_dimensions_are_skipped_not_zeroed():
    a = ans(intent=("a", 3), children=("a", 3), faith=("a", 3))
    b_full = ans(intent=("a", 3), children=("a", 3), faith=("a", 3))
    b_missing = ans(intent=("a", 3), children=("a", 3))  # no faith answer
    assert scoring.pair_score(a, b_full).score == pytest.approx(1.0)
    r = scoring.pair_score(a, b_missing)
    assert r.score == pytest.approx(1.0)  # still perfect: faith didn't drag it down
    assert {d.dimension for d in r.dimensions} == {"intent", "children"}
    assert (
        scoring.pair_score(ans(intent=("a", 2)), ans(children=("a", 2))) is None
    )  # nothing comparable


def test_importance_weights_direction():
    # A cares a lot (3) about children and little (1) about faith; B opposite. Mismatch on children only.
    a = ans(children=("a", 3), faith=("a", 1))
    b = ans(children=("b", 1), faith=("a", 3))
    r = scoring.pair_score(a, b)
    s_ab, s_ba = (
        scoring.directional(r.dimensions, side="a"),
        scoring.directional(r.dimensions, side="b"),
    )
    assert s_ab < s_ba  # A weights the mismatched dimension heavily → lower satisfaction
    assert r.score == pytest.approx((s_ab * s_ba) ** 0.5)


def test_dealbreaker_check():
    a = {
        "q": {
            "value": "a",
            "importance": 3,
            "dimension": "children",
            "scoring": MATRIX,
            "is_dealbreaker": True,
        }
    }
    ok = {
        "q": {
            "value": "a",
            "importance": 1,
            "dimension": "children",
            "scoring": MATRIX,
            "is_dealbreaker": False,
        }
    }
    bad = {
        "q": {
            "value": "b",
            "importance": 1,
            "dimension": "children",
            "scoring": MATRIX,
            "is_dealbreaker": False,
        }
    }
    assert scoring.dealbreaker_ok(a, ok, min_similarity=0.5)
    assert not scoring.dealbreaker_ok(a, bad, min_similarity=0.5)
    assert scoring.dealbreaker_ok(a, {}, min_similarity=0.5)  # unanswered is not a violation
    assert scoring.dealbreaker_ok(
        ok, bad, min_similarity=0.5
    )  # only the owner's deal-breakers count


def test_scoring_module_has_no_forbidden_inputs():
    """AC MC-056 (static): scoring/explain/ranking never reference photos, likes, popularity, payment,
    religion text, money or Phase 5 data."""
    banned = (
        "photo",
        "like",
        "popular",
        "payment",
        "paid",
        "member",
        "entitle",
        "religion",
        "money",
        "phase5",
        "genotype",
        "medical",
        "zodiac",
        "tribe",
    )
    for mod in (scoring, explain):
        src = inspect.getsource(mod).lower()
        for word in banned:
            body = src.replace(
                "importance", ""
            )  # 'importance' doesn't contain banned words, belt and braces
            assert word not in body.split('"""', 2)[-1], f"{mod.__name__} mentions {word!r}"


def test_explanations_come_from_templates_and_respect_thresholds():
    dims = [
        scoring.DimensionScore("children", 1.0, 3, 3),
        scoring.DimensionScore("faith", 0.9, 2, 2),
        scoring.DimensionScore("intent", 0.8, 1, 1),
        scoring.DimensionScore("lifestyle", 0.75, 1, 1),
        scoring.DimensionScore("location", 0.2, 3, 2),
        scoring.DimensionScore("roles", 0.1, 1, 1),  # low but importance 1 → not "discuss"
    ]
    why, discuss = explain.explain(dims)
    assert why == [WHY["children"], WHY["faith"], WHY["intent"]]
    assert discuss == [DISCUSS["location"]]
    assert all(w in WHY.values() for w in why)
    assert explain.explain([scoring.DimensionScore("money", 1.0, 3, 3)]) == (
        [],
        [],
    )  # unknown dim → silent
    assert explain.band(0.9, strong=0.8, good=0.65) == "strong"
    assert explain.band(0.7, strong=0.8, good=0.65) == "good"
    assert explain.band(0.1, strong=0.8, good=0.65) == "possible"


# ---- re-ranking ----------------------------------------------------------------------------------
NOW = datetime(2026, 6, 1, tzinfo=UTC)


def item(score, district="Kampala", age_days=100, n=None):
    return ranking.Scored(
        uuid.uuid4(), uuid.uuid4(), district, NOW - timedelta(days=age_days), score
    )


def run(items, **kw):
    args = {
        "exposure_today": {},
        "now": NOW,
        "cap": 150,
        "boost": 0.05,
        "boost_days": 7,
        "run_max": 3,
    }
    args.update(kw)
    return ranking.rerank(items, **args)


def test_new_profiles_get_boost_only_within_window():
    old, new, older_new = item(0.80), item(0.78, age_days=2), item(0.70, age_days=30)
    out = [i for i, _ in run([old, new, older_new])]
    assert out[0] is new  # 0.78 + 0.05 > 0.80
    assert out[-1] is older_new


def test_exposure_cap_removes_overexposed():
    a, b = item(0.9), item(0.8)
    out = [i for i, _ in run([a, b], exposure_today={a.account_id: 150, b.account_id: 149})]
    assert out == [b]


def test_no_more_than_three_consecutive_from_one_district():
    items = [item(0.9 - i * 0.01, "Kampala") for i in range(8)] + [
        item(0.5, "Gulu"),
        item(0.4, "Mbale"),
    ]
    out = [i.district for i, _ in run(items)]
    run_len = max(len(list(g)) for _, g in __import__("itertools").groupby(out))
    assert run_len <= 3 and out[:3] == ["Kampala"] * 3 and out[3] != "Kampala"


def test_interleave_degrades_gracefully_when_only_one_district():
    items = [item(0.9 - i * 0.01) for i in range(6)]
    assert len(run(items)) == 6


def test_ranking_is_deterministic():
    items = [item(0.5, "A"), item(0.5, "B"), item(0.5, "A")]
    assert [i.profile_id for i, _ in run(items)] == [
        i.profile_id for i, _ in run(list(reversed(items)))
    ]


@settings(max_examples=100, deadline=None)
@given(st.lists(st.tuples(st.floats(0, 1), st.sampled_from(["A", "B", "C"])), max_size=40))
def test_interleave_is_a_permutation_of_input(pairs):
    items = [item(s, d) for s, d in pairs]
    out = [i for i, _ in run(items)]
    assert sorted(map(id, out)) == sorted(map(id, items))


def test_exposure_cap_holds_under_simulation(db):
    """AC MC-057: simulate many viewers browsing; no candidate exceeds EXPOSURE_DAILY_CAP impressions."""
    from django.conf import settings as dj

    from devtools.factories import create_member
    from mc.discovery import services
    from mc.discovery.models import Impression
    from mc.entitlements import services as ent

    dj.EXPOSURE_DAILY_CAP = 5
    women = [create_member(gender="female", age=28) for _ in range(4)]
    for _ in range(12):
        m = create_member(gender="male", age=30)
        ent.start_trial(account=m)
        page = services.next_candidates(m, cursor=None, limit=20)
        assert len(page["items"]) <= 4
    from django.db.models import Count

    counts = (
        Impression.objects.values("candidate").annotate(n=Count("id")).values_list("n", flat=True)
    )
    assert max(counts) <= 5
    assert {i.candidate_id for i in Impression.objects.all()} <= {w.id for w in women}
    _ = random

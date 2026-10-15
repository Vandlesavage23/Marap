import json

import pytest
from django.db import connection
from hypothesis import given
from hypothesis import strategies as st

from mc.accounts.tests.helpers import bearer
from mc.profiles.tests.helpers import consent, verified_client
from mc.questionnaire import selectors
from mc.questionnaire.models import Answer, Question
from mc.questionnaire.scoring import similarity
from mc.verification.tests.helpers import J, new_user

pytestmark = pytest.mark.django_db


def put(c, r, *answers):
    return c.put("/api/v1/me/answers", {"answers": list(answers)}, **bearer(r), **J)


def valid_answer(q, **kw):
    if q.type == "single":
        value = q.options[0]["value"]
    elif q.type == "multi":
        value = [q.options[0]["value"]]
    else:
        value = 3
    return {"question": q.key, "value": value, **kw}


def core_answers():
    return [valid_answer(q) for q in selectors.active_questions().filter(is_core=True)]


# ---- seed data -----------------------------------------------------------------------------
def test_seed_has_25_core_and_special_questions():
    assert Question.objects.filter(is_core=True, active=True).count() == 25
    special = Question.objects.filter(is_special=True)
    assert special.count() == 3 and not special.filter(is_core=True).exists()
    assert all(q.consent_kind for q in special)
    dims = set(Question.objects.values_list("dimension", flat=True))
    assert dims == set(Question.Dimension.values)


def test_seed_loader_is_idempotent():
    from mc.questionnaire.loader import load

    before = Question.objects.count()
    load(Question)
    assert Question.objects.count() == before


def test_every_scoring_matrix_is_symmetric_bounded_and_complete():
    for q in Question.objects.filter(type="single"):
        m = q.scoring["matrix"]
        values = {o["value"] for o in q.options}
        assert set(m) == values, q.key
        for a in values:
            assert set(m[a]) == values, q.key
            assert m[a][a] == 1, q.key
            for b in values:
                assert 0 <= m[a][b] <= 1 and m[a][b] == m[b][a], (q.key, a, b)


def test_money_attitude_is_never_scoring_allowed():
    assert Question.objects.get(key="money_attitude").scoring_allowed is False
    assert Question.objects.get(key="faith_practice").scoring_allowed is True


# ---- scoring functions -----------------------------------------------------------------------
def test_similarity_kinds():
    m = {"kind": "matrix", "matrix": {"a": {"a": 1, "b": 0.25}, "b": {"a": 0.25, "b": 1}}}
    assert similarity(m, "a", "b") == 0.25 and similarity(m, "a", "zzz") is None
    s = {"kind": "scale", "min": 1, "max": 5}
    assert similarity(s, 1, 5) == 0 and similarity(s, 3, 3) == 1 and similarity(s, 2, 3) == 0.75
    j = {"kind": "jaccard"}
    assert (
        similarity(j, ["x", "y"], ["y", "z"]) == pytest.approx(1 / 3)
        and similarity(j, [], []) is None
    )
    assert similarity(m, None, "a") is None and similarity({"kind": "?"}, 1, 1) is None


@given(st.integers(1, 5), st.integers(1, 5))
def test_scale_similarity_symmetric_and_bounded(a, b):
    s = {"kind": "scale", "min": 1, "max": 5}
    assert similarity(s, a, b) == similarity(s, b, a)
    assert 0 <= similarity(s, a, b) <= 1


@given(st.sets(st.sampled_from("abcdef")), st.sets(st.sampled_from("abcdef")))
def test_jaccard_symmetric(a, b):
    j = {"kind": "jaccard"}
    assert similarity(j, list(a), list(b)) == similarity(j, list(b), list(a))


# ---- API ---------------------------------------------------------------------------------------
def test_requires_auth_and_verification():
    c, r = new_user()
    assert c.get("/api/v1/questions", **bearer(r)).status_code == 200  # reference data
    assert put(c, r, {"question": "children_want", "value": "yes"}).status_code == 403
    from django.test import Client

    assert Client(headers={"host": "api.mc.test"}).get("/api/v1/questions").status_code == 401


def test_save_and_read_answers_and_core_complete():
    c, r, acct = verified_client()
    resp = put(c, r, *core_answers()[:5])
    assert resp.status_code == 200 and resp.json()["core_complete"] is False
    resp = put(c, r, *core_answers())
    assert resp.json()["core_complete"] is True and len(resp.json()["items"]) == 25
    assert selectors.core_complete(acct.id)


def test_upsert_changes_value_importance_dealbreaker():
    c, r, _ = verified_client()
    put(
        c, r, {"question": "children_want", "value": "yes", "importance": 3, "is_dealbreaker": True}
    )
    put(c, r, {"question": "children_want", "value": "no", "importance": 1})
    a = Answer.objects.get()
    assert (a.value, a.importance, a.is_dealbreaker) == ("no", 1, False)


@pytest.mark.parametrize(
    "bad",
    [
        {"question": "children_want", "value": "maybe"},
        {"question": "children_want", "value": ["yes"]},
        {"question": "free_time", "value": "family"},
        {"question": "free_time", "value": []},
        {"question": "free_time", "value": ["family", "family"]},
        {"question": "free_time", "value": ["nope"]},
        {"question": "social_energy", "value": 9},
        {"question": "social_energy", "value": True},
        {"question": "social_energy", "value": "3"},
        {"question": "children_want", "value": "yes", "importance": 4},
        {"question": "conflict_style", "value": "talk_now", "is_dealbreaker": True},  # not allowed
        {"question": "no_such_question", "value": "x"},
    ],
)
def test_invalid_answers_rejected(bad):
    c, r, _ = verified_client()
    assert put(c, r, bad).status_code == 422
    assert Answer.objects.count() == 0


def test_batch_is_all_or_nothing_and_rejects_duplicates():
    c, r, _ = verified_client()
    resp = put(
        c, r, {"question": "children_want", "value": "yes"}, {"question": "alcohol", "value": "bad"}
    )
    assert resp.status_code == 422 and Answer.objects.count() == 0
    assert (
        put(
            c,
            r,
            {"question": "alcohol", "value": "never"},
            {"question": "alcohol", "value": "never"},
        ).status_code
        == 422
    )
    assert put(c, r).status_code == 422
    assert (
        put(c, r, {"question": "alcohol", "value": "never", "extra": 1}).status_code == 200
    )  # nested unknown ignored by DRF


def test_unknown_top_level_field_rejected():
    c, r, _ = verified_client()
    resp = c.put(
        "/api/v1/me/answers",
        {"answers": [{"question": "alcohol", "value": "never"}], "x": 1},
        **bearer(r),
        **J,
    )
    assert resp.status_code == 422


# ---- special data ----------------------------------------------------------------------------------
def test_special_answer_needs_consent_then_is_encrypted_at_rest():
    c, r, _ = verified_client()
    resp = put(c, r, {"question": "faith_practice", "value": "weekly"})
    assert resp.status_code == 422 and resp.json()["missing_consent"] == "special_religion"
    consent(c, r, "special_religion")
    assert (
        put(c, r, {"question": "faith_practice", "value": "weekly", "importance": 3}).status_code
        == 200
    )
    with connection.cursor() as cur:
        cur.execute("SELECT value, value_enc FROM questionnaire_answer")
        value, enc = cur.fetchone()
    assert value is None and enc.startswith("v1:") and "weekly" not in enc  # DB inspection test
    got = c.get("/api/v1/me/answers", **bearer(r)).json()["items"][0]
    assert got["value"] == "weekly"


def test_withdrawing_consent_deletes_special_answers(django_capture_on_commit_callbacks):
    from mc.accounts.tests.helpers import bearer as b

    c, r, _ = verified_client()
    consent(c, r, "special_religion", "special_finance")
    put(
        c,
        r,
        {"question": "faith_practice", "value": "weekly"},
        {"question": "money_attitude", "value": "joint"},
        {"question": "alcohol", "value": "never"},
    )
    with django_capture_on_commit_callbacks(execute=True):
        consent(c, r, "special_religion", granted=False)
    keys = set(Answer.objects.values_list("question__key", flat=True))
    assert keys == {"money_attitude", "alcohol"}
    _ = b


def test_answers_for_scoring_excludes_forbidden_and_stale():
    c, r, acct = verified_client()
    consent(c, r, "special_religion", "special_finance")
    put(
        c,
        r,
        {"question": "faith_practice", "value": "weekly"},
        {"question": "money_attitude", "value": "joint"},
        {"question": "alcohol", "value": "never"},
        {"question": "social_energy", "value": 4},
    )
    scored = selectors.answers_for_scoring([acct.id])[acct.id]
    assert set(scored) == {"faith_practice", "alcohol", "social_energy"}  # money never ranks
    assert scored["faith_practice"]["value"] == "weekly"
    Question.objects.filter(key="alcohol").update(
        version=2
    )  # question changed → old answer is stale
    assert "alcohol" not in selectors.answers_for_scoring([acct.id])[acct.id]
    assert selectors.core_complete(acct.id) is False


def test_static_scoring_never_reads_special_or_forbidden_columns():
    """Forbidden inputs (CLAUDE.md rule 4 / Bible §10.6) can't leak in via the selector's query shape."""
    import inspect

    src = inspect.getsource(selectors.answers_for_scoring)
    assert "scoring_allowed" in src and "value_enc" not in src
    for forbidden in ("photo", "payment", "likes", "popularity", "religion"):
        assert forbidden not in src
    assert json  # silence unused import in some configs

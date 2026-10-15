from datetime import timedelta

import pytest
from django.utils import timezone

from devtools.factories import create_member
from mc.discovery import services
from mc.discovery.models import Impression
from mc.interests.models import Interest, InterestSnapshot
from mc.profiles import search
from mc.profiles.models import Profile
from mc.safety.models import Block

pytestmark = pytest.mark.django_db


def viewer_ctx(acct):
    from mc.profiles import selectors

    return selectors.viewer_context_for(acct)


def pool(viewer, **kw):
    ctx = viewer_ctx(viewer)
    rows = search.hard_filter_candidates(
        ctx,
        exclude_account_ids=services._exclusions(
            viewer.id, timezone.now(), include_recent=kw.get("recent", True)
        ),
        limit=500,
    )
    return {r["account_id"] for r in rows}


def test_baseline_opposite_gender_live_active_only():
    me = create_member(gender="male", age=30)
    woman = create_member(gender="female", age=28)
    man = create_member(gender="male", age=29)
    draft = create_member(gender="female", age=28, live=False)
    suspended = create_member(gender="female", age=28)
    suspended.status = "suspended"
    suspended.save()
    got = pool(me)
    assert got == {woman.id}
    assert (
        man.id not in got and draft.id not in got and suspended.id not in got and me.id not in got
    )


@pytest.mark.parametrize(
    ("viewer_pref", "cand_age", "cand_pref", "visible"),
    [
        ((25, 35), 30, (25, 40), True),
        ((25, 35), 24, (18, 40), False),  # younger than viewer's min
        ((25, 35), 36, (18, 40), False),  # older than viewer's max
        ((25, 35), 25, (18, 40), True),  # boundary
        ((25, 35), 35, (18, 40), True),  # boundary
        (
            (25, 35),
            30,
            (18, 29),
            False,
        ),  # viewer (age 30) older than candidate's max → mutual ranges
        ((25, 35), 30, (31, 40), False),  # viewer younger than candidate's min
        ((25, 35), 30, (30, 30), True),  # exactly viewer's age
    ],
)
def test_mutual_age_ranges(viewer_pref, cand_age, cand_pref, visible):
    me = create_member(gender="male", age=30, age_min=viewer_pref[0], age_max=viewer_pref[1])
    cand = create_member(gender="female", age=cand_age, age_min=cand_pref[0], age_max=cand_pref[1])
    assert (cand.id in pool(me)) is visible


def test_age_bounds_use_exact_birthday_not_year_difference():
    from datetime import date

    today = date(2026, 6, 15)
    assert search.birth_date_for_age(today, 18) == date(2008, 6, 15)
    assert search.birth_date_for_age(date(2028, 2, 29), 18) == date(2010, 2, 28)  # leap-day clamp


# ---- married opt-in, both directions -----------------------------------------------------------
def test_married_candidates_hidden_unless_viewer_opted_in():
    man = create_member(
        gender="male", age=35, marital_status="married_customary", show_married_profiles=False
    )
    woman_default = create_member(gender="female", age=30, age_min=25, age_max=45)
    woman_optin = create_member(
        gender="female", age=30, show_married_profiles=True, age_min=25, age_max=45
    )
    assert man.id not in pool(woman_default)
    assert man.id in pool(woman_optin)


def test_married_viewer_only_shown_to_candidates_who_opted_in():
    man = create_member(
        gender="male", age=35, marital_status="married_islamic", show_married_profiles=True
    )
    optin = create_member(
        gender="female", age=30, show_married_profiles=True, age_min=25, age_max=45
    )
    optout = create_member(
        gender="female", age=30, show_married_profiles=False, age_min=25, age_max=45
    )
    got = pool(man)
    assert optin.id in got and optout.id not in got


def test_married_feature_flag_off_hides_everything_married(settings):
    settings.MARRIED_PROFILES_ENABLED = False
    man = create_member(
        gender="male", age=35, marital_status="married_customary", show_married_profiles=True
    )
    woman = create_member(
        gender="female", age=30, show_married_profiles=True, age_min=25, age_max=45
    )
    assert pool(man) == set() and man.id not in pool(woman)


# ---- distance / diaspora -------------------------------------------------------------------------
def test_max_distance_filter_with_coordinates():
    me = create_member(gender="male", age=30, lat=0.35, lng=32.58, max_distance_km=50)  # Kampala
    near = create_member(gender="female", age=28, lat=0.32, lng=32.57)  # ~4 km
    far = create_member(gender="female", age=28, lat=2.77, lng=32.30, district="Gulu")  # ~270 km
    unknown = create_member(gender="female", age=28)  # no coordinates → not excluded
    got = pool(me)
    assert near.id in got and unknown.id in got and far.id not in got


def test_diaspora_rules_both_ways():
    me = create_member(gender="male", age=30, include_diaspora=False)
    abroad = create_member(gender="female", age=28, district="abroad", diaspora_country="GB")
    assert abroad.id not in pool(me)
    me2 = create_member(gender="male", age=30, include_diaspora=True)
    assert abroad.id in pool(me2)
    local_who_declines = create_member(gender="female", age=28, include_diaspora=False)
    diaspora_viewer = create_member(gender="male", age=30, district="abroad", diaspora_country="US")
    assert local_who_declines.id not in pool(diaspora_viewer)
    assert abroad.id in pool(diaspora_viewer)  # distance never applies to diaspora viewers


# ---- children ----------------------------------------------------------------------------------------
def test_accept_has_children_both_directions():
    me = create_member(gender="male", age=30, accept_has_children=False)
    mum = create_member(gender="female", age=28, has_children="yes_living_with_me")
    no_kids = create_member(gender="female", age=28, has_children="no")
    assert pool(me) == {no_kids.id}
    dad = create_member(gender="male", age=30, has_children="yes_not_living_with_me")
    strict = create_member(gender="female", age=28, accept_has_children=False)
    relaxed = create_member(gender="female", age=28, accept_has_children=True)
    got = pool(dad)
    assert relaxed.id in got and strict.id not in got and mum.id in got


# ---- blocks, interests, repeat hiding, not_relevant ------------------------------------------------
def test_blocks_remove_both_ways():
    me = create_member(gender="male", age=30)
    blocked_by_me = create_member(gender="female", age=28)
    blocked_me = create_member(gender="female", age=28)
    ok = create_member(gender="female", age=28)
    Block.objects.create(blocker=me, blocked=blocked_by_me)
    Block.objects.create(blocker=blocked_me, blocked=me)
    assert pool(me) == {ok.id}
    # and symmetric from their side
    assert me.id not in pool(blocked_me) and me.id not in pool(blocked_by_me)


def pending(a, b):
    snap = InterestSnapshot.objects.create(text="x", display_name="x")
    return Interest.objects.create(
        sender=a,
        recipient=b,
        snapshot=snap,
        idempotency_key=f"k{a.id.hex[:8]}{b.id.hex[:8]}",
        expires_at=timezone.now() + timedelta(days=30),
    )


def test_pending_interest_either_direction_excluded():
    me = create_member(gender="male", age=30)
    sent_to = create_member(gender="female", age=28)
    got_from = create_member(gender="female", age=28)
    ok = create_member(gender="female", age=28)
    pending(me, sent_to)
    pending(got_from, me)
    assert pool(me) == {ok.id}
    Interest.objects.filter(sender=me).update(status="passed")
    assert sent_to.id in pool(me)  # only *pending* interests exclude


def test_recently_shown_hidden_unless_pool_exhausted():
    me = create_member(gender="male", age=30)
    seen = create_member(gender="female", age=28)
    fresh = create_member(gender="female", age=28)
    Impression.objects.create(
        viewer=me, candidate=seen, score=0.5, model_version="v1", position=0,
        shown_at=timezone.now() - timedelta(days=5),
    )  # fmt: skip
    assert pool(me) == {fresh.id}
    Impression.objects.filter(viewer=me).update(shown_at=timezone.now() - timedelta(days=40))
    assert pool(me) == {fresh.id, seen.id}  # outside the 30-day window
    Impression.objects.filter(viewer=me).update(shown_at=timezone.now() - timedelta(days=5))
    Profile.objects.filter(account=fresh).update(status="draft")
    entries, _ = services.build_ranked_pool(me)  # only `seen` remains, via the exhaustion fallback
    assert [e.account_id for e in entries] == [str(seen.id)]


def test_not_relevant_is_hidden_forever_even_when_pool_exhausted():
    me = create_member(gender="male", age=30)
    nope = create_member(gender="female", age=28)
    Impression.objects.create(
        viewer=me,
        candidate=nope,
        score=0.5,
        model_version="v1",
        position=0,
        shown_at=timezone.now() - timedelta(days=400),
        action="not_relevant",
    )
    entries, _ = services.build_ranked_pool(me)
    assert entries == []


# ---- deal-breakers -------------------------------------------------------------------------------------
def test_dealbreakers_enforced_from_both_sides():
    from devtools.factories import default_answer_values

    base = default_answer_values()
    me = create_member(
        gender="male",
        age=30,
        answer_values={**base, "children_want": "yes"},
        dealbreakers=("children_want",),
    )
    wants = create_member(gender="female", age=28, answer_values={**base, "children_want": "yes"})
    unsure = create_member(
        gender="female", age=28, answer_values={**base, "children_want": "unsure"}
    )  # 0.5 ≥ threshold
    no_kids = create_member(gender="female", age=28, answer_values={**base, "children_want": "no"})
    got = {e.account_id for e in services.build_ranked_pool(me)[0]}
    assert str(wants.id) in got and str(unsure.id) in got and str(no_kids.id) not in got
    # candidate's own deal-breaker also removes the viewer from *their* pool
    her = create_member(
        gender="female",
        age=28,
        answer_values={**base, "children_want": "no"},
        dealbreakers=("children_want",),
    )
    wanting_man = create_member(
        gender="male", age=30, answer_values={**base, "children_want": "yes"}
    )
    assert str(wanting_man.id) not in {e.account_id for e in services.build_ranked_pool(her)[0]}

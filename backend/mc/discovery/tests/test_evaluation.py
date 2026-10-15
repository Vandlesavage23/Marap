import json
from io import StringIO

import pytest
from django.core.management import call_command
from django.utils import timezone
from hypothesis import given
from hypothesis import strategies as st

from devtools.factories import create_member
from mc.discovery import evaluation
from mc.discovery.models import Impression

pytestmark = pytest.mark.django_db


def test_gini_properties():
    assert evaluation.gini([5, 5, 5, 5]) == 0
    assert evaluation.gini([0, 0, 0, 10]) == pytest.approx(0.75)
    assert evaluation.gini([]) == 0 and evaluation.gini([0, 0]) == 0


@given(st.lists(st.floats(0, 1000), min_size=1, max_size=50))
def test_gini_bounded(xs):
    assert 0 <= evaluation.gini(xs) <= 1


def imp(v, c, action=None):
    return Impression.objects.create(
        viewer=v,
        candidate=c,
        score=0.7,
        model_version="v1",
        position=0,
        shown_at=timezone.now(),
        action=action,
    )


def test_report_outputs_mutual_rate_and_gini_groups():
    m1, m2 = (
        create_member(gender="male", age=30, district="Kampala"),
        create_member(gender="male", age=40, district="Gulu"),
    )
    f1, f2 = (
        create_member(gender="female", age=27, district="Kampala"),
        create_member(gender="female", age=33, district="Gulu"),
    )
    imp(m1, f1, "interest")
    imp(f1, m1, "interest")  # mutual
    imp(m2, f2, "interest")  # one-sided
    imp(m1, f2)
    imp(m1, f2)
    r = evaluation.report()
    assert (
        r["mutual_interest"]["mutual_pairs"] == 1
        and r["mutual_interest"]["pairs_with_interest"] == 2
    )
    assert r["mutual_interest"]["mutual_interest_rate"] == 0.5
    assert set(r["exposure_gini"]) == {"gender", "age_band", "district"}
    assert set(r["exposure_gini"]["gender"]) == {"male", "female"}
    assert "25-29" in r["exposure_gini"]["age_band"]
    out = StringIO()
    call_command("ranking_report", "--days", "7", stdout=out)
    assert json.loads(out.getvalue())["window_days"] == 7

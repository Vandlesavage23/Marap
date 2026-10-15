import json
import uuid
from datetime import timedelta

import pytest
from django.db import connection
from django.utils import timezone
from freezegun import freeze_time

from mc.accounts.tests.helpers import bearer
from mc.interests.tests.helpers import member, pair, send
from mc.messaging.tests.helpers import matched, say
from mc.safety import reports, selectors
from mc.safety.models import Block, Case, Report, ReportEvidence
from mc.verification.tests.helpers import J

pytestmark = pytest.mark.django_db


def file_report(
    who,
    target_pid,
    category="harassment",
    context_type="profile",
    context_id=None,
    key=None,
    **extra,
):
    body = {"profile_id": target_pid, "category": category, "context_type": context_type, **extra}
    if context_id:
        body["context_id"] = context_id
    return who[0].post(
        "/api/v1/reports", body, **bearer(who[1]), HTTP_IDEMPOTENCY_KEY=key or uuid.uuid4().hex, **J
    )


def evidence_of(report):
    return [
        (e.kind, json.loads(e.content))
        for e in ReportEvidence.objects.filter(report=report).order_by("position")
    ]


@pytest.mark.parametrize(
    ("category", "sev"),
    [
        ("threat", "s1"),
        ("underage", "s1"),
        ("scam", "s2"),
        ("financial_request", "s2"),
        ("impersonation", "s2"),
        ("married_concealed", "s2"),
        ("harassment", "s3"),
        ("sexual_content", "s3"),
        ("fake_profile", "s3"),
        ("spam", "s4"),
        ("other", "s4"),
    ],
)
def test_severity_routing_and_sla(category, sev, settings):
    m, f = pair()
    assert file_report(m, f[3], category).status_code == 201
    assert Case.objects.get().severity == sev and Report.objects.get().severity == sev
    assert settings.SAFETY_SLA_HOURS[sev] in (1, 4, 24, 120)


def test_sla_deadlines_match_planning_package():
    m, f = pair()
    with freeze_time(timezone.now()):
        file_report(m, f[3], "threat")
        assert Case.objects.get().sla_due_at == timezone.now() + timedelta(hours=1)
    Case.objects.all().delete()
    Report.objects.all().delete()
    m2, f2 = pair()
    with freeze_time(timezone.now()):
        file_report(m2, f2[3], "spam")
        assert Case.objects.get().sla_due_at == timezone.now() + timedelta(days=5)


def test_profile_report_captures_profile_snapshot():
    m, f = pair()
    resp = file_report(m, f[3], "fake_profile", text="photos look stolen")
    assert (
        resp.status_code == 201
        and resp.json()["status"] == "received"
        and resp.json()["blocked"] is False
    )
    kinds = evidence_of(Report.objects.get())
    assert [k for k, _ in kinds] == ["profile_snapshot"]
    snap = kinds[0][1]
    assert (
        snap["display_name"]
        and snap["description"].startswith("I am a kind")
        and len(snap["photo_media_ids"]) == 2
    )
    assert Report.objects.get().text == "photos look stolen"


def test_message_report_copies_up_to_20_prior_messages_in_order():
    m, f, mid = matched()
    from mc.matches.models import Match

    Match.objects.update(created_at=timezone.now() - timedelta(days=10))
    for i in range(25):
        who = m if i % 2 == 0 else f
        who_text = f"line {i}"
        assert say(who, mid, who_text).status_code == 201
    bad = say(f, mid, "you owe me money").json()
    from mc.messaging.models import Message

    msg_id = bad["id"]
    resp = file_report(m, f[3], "harassment", "message", msg_id)
    assert resp.status_code == 201
    rows = [c for k, c in evidence_of(Report.objects.get()) if k == "message"]
    assert len(rows) == 21 and rows[-1]["reported"] and rows[-1]["body"] == "you owe me money"
    assert [r["body"] for r in rows[:-1]] == [
        f"line {i}" for i in range(5, 25)
    ]  # last 20 before it, oldest first
    assert rows[-1]["from"] == "subject" and {r["from"] for r in rows} == {"reporter", "subject"}
    assert Message.objects.count() >= 26  # originals untouched; evidence is a copy


def test_evidence_and_text_are_encrypted_at_rest():
    m, f, mid = matched()
    from mc.matches.models import Match

    Match.objects.update(created_at=timezone.now() - timedelta(days=10))
    bad = say(f, mid, "SECRET-EVIDENCE-PHRASE").json()
    file_report(m, f[3], "scam", "message", bad["id"], text="SECRET-NOTE")
    with connection.cursor() as cur:
        cur.execute("SELECT content FROM safety_reportevidence")
        assert all(r[0].startswith("v1:") and "SECRET" not in r[0] for r in cur.fetchall())
        cur.execute("SELECT text FROM safety_report")
        assert cur.fetchone()[0].startswith("v1:")


def test_message_report_only_by_a_member_about_the_sender():
    m, f, mid = matched()
    from mc.matches.models import Match

    Match.objects.update(created_at=timezone.now() - timedelta(days=10))
    mine = say(m, mid, "mine").json()["id"]
    theirs = say(f, mid, "theirs").json()["id"]
    stranger = member("female")
    assert (
        file_report(stranger, f[3], "harassment", "message", theirs).status_code == 404
    )  # not in that chat
    assert (
        file_report(m, f[3], "harassment", "message", mine).status_code == 404
    )  # subject didn't send it
    assert file_report(m, f[3], "harassment", "message").status_code == 422  # context_id required
    assert file_report(m, f[3], "harassment", "message", str(uuid.uuid4())).status_code == 404
    assert file_report(m, f[3], "harassment", "message", theirs).status_code == 201


def test_interest_report_evidence_is_the_snapshot():
    m, f = pair()
    iid = send(m[0], m[1], f[3]).json()["id"]
    assert file_report(f, m[3], "sexual_content", "interest", iid).status_code == 201
    kinds = dict(evidence_of(Report.objects.get()))
    assert (
        kinds["interest_snapshot"]["text"].startswith("I am a kind")
        and kinds["interest_snapshot"]["from"] == "subject"
    )
    stranger = member("female")
    assert file_report(stranger, m[3], "harassment", "interest", iid).status_code == 404


def test_report_with_also_block_blocks_in_same_transaction():
    m, f, mid = matched()
    resp = file_report(m, f[3], "harassment", also_block=True)
    assert resp.status_code == 201 and resp.json()["blocked"] is True
    assert Block.objects.filter(blocker=m[2], blocked=f[2]).exists()
    from mc.matches.models import Match

    assert Match.objects.get(id=mid).status == "blocked"


def test_reports_join_one_open_case_and_escalate_severity():
    m, f = pair()
    third = member("male")
    file_report(m, f[3], "spam")
    case = Case.objects.get()
    assert case.severity == "s4"
    with freeze_time(timezone.now()):
        file_report(third, f[3], "threat")
        case.refresh_from_db()
        assert case.severity == "s1" and case.sla_due_at <= timezone.now() + timedelta(
            hours=1, seconds=5
        )
    file_report(m, f[3], "spam", key="other-key-1234")
    assert (
        Case.objects.count() == 1
        and Report.objects.count() == 3
        and Case.objects.get().severity == "s1"
    )  # never downgrades


def test_idempotent_retry_and_validation_and_limits(settings):
    m, f = pair()
    a = file_report(m, f[3], key="report-key-12345")
    b = file_report(m, f[3], key="report-key-12345")
    assert a.json() == b.json() and Report.objects.count() == 1
    assert file_report(m, f[3], "made_up").status_code == 422
    assert file_report(m, m[3]).status_code == 422
    assert file_report(m, str(uuid.uuid4())).status_code == 404
    assert file_report(m, f[3], text="x" * 1201).status_code == 422
    assert (
        m[0]
        .post(
            "/api/v1/reports",
            {"profile_id": f[3], "category": "spam", "context_type": "profile"},
            **bearer(m[1]),
            **J,
        )
        .status_code
        == 422
    )  # no key
    settings.REPORTS_PER_DAY = 2
    from mc.common.redis import get_redis

    get_redis().flushdb()
    codes = [file_report(m, f[3], key=f"limit-key-{i}-xyz").status_code for i in range(4)]
    assert codes == [201, 201, 429, 429]


def test_s1_report_raises_an_alert_log(caplog):
    import logging

    m, f = pair()
    with caplog.at_level(logging.WARNING):
        file_report(m, f[3], "underage")
    assert any(getattr(r, "alert", "") == "s1_report" for r in caplog.records)


def test_report_requires_auth_and_moderators_see_a_prioritised_queue():
    from django.test import Client

    assert (
        Client(headers={"host": "api.mc.test"}).post("/api/v1/reports", {}, **J).status_code == 401
    )
    m, f = pair()
    third = member("female")
    file_report(m, f[3], "spam")
    file_report(m, third[3], "threat")
    queue = list(selectors.open_cases())
    assert [c.severity for c in queue] == ["s1", "s4"]
    with freeze_time(timezone.now() + timedelta(hours=2)):
        assert [c.severity for c in selectors.sla_breached()] == ["s1"]
    _ = reports

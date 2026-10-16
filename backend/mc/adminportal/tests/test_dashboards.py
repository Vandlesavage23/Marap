"""Staff dashboards (Bible §15): funnel, density, reconciliation, SLA queues and the feature-flag page."""

import uuid
from datetime import UTC, date, datetime, timedelta

import pytest
from django.utils import timezone

from devtools.factories import create_member
from mc.accounts.models import Account
from mc.adminportal import dashboards, policies
from mc.adminportal.models import StaffSession
from mc.adminportal.tests.helpers import full_login, next_code, staff
from mc.audit.models import AuditEvent
from mc.billing import admin_ops, recon_reports
from mc.billing.models import ReconciliationReport
from mc.common.errors import Forbidden
from mc.common.timeutil import KAMPALA
from mc.entitlements.models import Entitlement
from mc.flags.models import FeatureFlag
from mc.interests.models import Interest
from mc.matches.models import Match
from mc.profiles.models import Profile

pytestmark = pytest.mark.django_db

NOW = datetime(2026, 6, 15, 9, 0, tzinfo=UTC)
TODAY = date(2026, 6, 15)


def members(n, **kw):
    return [create_member(**kw) for _ in range(n)]


def ids(items):
    return [getattr(x, "account", x) for x in items]


# ---------------------------------------------------------------- role matrix for the new pages
NEW_PAGES = {
    "/dashboards/funnel": "dashboard.funnel",
    "/dashboards/density": "dashboard.density",
    "/payments/reconciliation": "payments.reconciliation",
    "/flags": "config.flags",
}


def test_new_pages_follow_the_role_matrix_and_denials_are_audited():
    expected = {
        "support": set(),
        "verification_reviewer": set(),
        "trust_safety": {"dashboard.density"},
        "payments_ops": {"dashboard.funnel", "payments.reconciliation"},
        "privacy_officer": {"dashboard.funnel", "dashboard.density", "payments.reconciliation"},
        "engineer_oncall": {"config.flags"},
        "superadmin": {"config.flags"},
    }
    assert set(expected) == set(policies.PERMISSIONS)
    for role, allowed in expected.items():
        s = staff([role], email=f"{role}@marriageconnect.ug")
        c = full_login(s)
        for path, perm in NEW_PAGES.items():
            assert c.get(path).status_code == (200 if perm in allowed else 403), (role, path)
            assert (perm in policies.permissions_of(s)) == (perm in allowed), (role, perm)
        denied = AuditEvent.objects.filter(action="admin.denied", actor_id=s.id).count()
        assert denied == len(NEW_PAGES) - len(allowed), role


def test_unauthenticated_requests_to_new_pages_redirect_to_login():
    from mc.adminportal.tests.helpers import client

    c = client()
    for path in NEW_PAGES:
        r = c.get(path)
        assert r.status_code == 302 and r["Location"].endswith("/login"), path


def test_every_successful_view_is_audited():
    c = full_login(staff(["privacy_officer"]))
    for path in ("/dashboards/funnel", "/dashboards/density", "/payments/reconciliation"):
        assert c.get(path).status_code == 200
    audited = {
        e.metadata["path"]
        for e in AuditEvent.objects.filter(action="admin.view", actor_type="staff")
    }
    assert {"/dashboards/funnel", "/dashboards/density", "/payments/reconciliation"} <= audited


def test_no_dashboard_permission_for_oncall_engineers_who_may_not_see_production_data():
    perms = policies.PERMISSIONS["engineer_oncall"]
    assert perms == {"config.flags"}


# ---------------------------------------------------------------- date range
def test_parse_range():
    p = dashboards.parse_range
    d = p("", "", now=NOW)
    assert (d.first, d.last, d.error) == (TODAY - timedelta(days=29), TODAY, "")
    assert p("2026-06-01", "2026-06-10", now=NOW).first == date(2026, 6, 1)
    one = p("2026-06-10", "2026-06-10", now=NOW)
    assert one.start == datetime(2026, 6, 10, tzinfo=KAMPALA) and one.end == datetime(
        2026, 6, 11, tzinfo=KAMPALA
    )
    assert p("2026-06-01", "", now=NOW).last == TODAY
    assert p("", "2026-06-05", now=NOW).first == TODAY - timedelta(days=29)
    assert p("2026-06-01", "2030-01-01", now=NOW).last == TODAY  # future clamped
    for bad in (
        ("nope", ""),
        ("2026-13-01", "2026-06-02"),
        ("2026-06-10", "2026-06-01"),
        ("2024-01-01", "2026-06-15"),
    ):
        r = p(*bad, now=NOW)
        assert r.error and r.last == TODAY and (r.last - r.first).days == 29, bad


def test_range_uses_kampala_days_not_utc():
    # 21:30 UTC on 14 June is already 15 June in Kampala (UTC+3)
    late = datetime(2026, 6, 14, 21, 30, tzinfo=UTC)
    assert dashboards.parse_range("", "", now=late).last == date(2026, 6, 15)


# ---------------------------------------------------------------- SLA badges
def test_sla_badge_states_and_wording():
    b = dashboards.sla_badge
    assert b(NOW + timedelta(hours=3, minutes=10), now=NOW) == {
        "state": "ok",
        "text": "Due in 3h 10m",
    }
    assert b(NOW + timedelta(minutes=59), now=NOW) == {"state": "soon", "text": "Due in 59m"}
    assert b(NOW + timedelta(hours=1), now=NOW)["state"] == "soon"
    assert b(NOW + timedelta(days=2, hours=5), now=NOW)["text"] == "Due in 2d 5h"
    assert b(NOW, now=NOW)["state"] == "soon"  # exactly due is not yet overdue
    assert b(NOW - timedelta(minutes=1), now=NOW) == {"state": "overdue", "text": "Overdue by 1m"}
    assert b(NOW - timedelta(hours=26), now=NOW)["text"] == "Overdue by 1d 2h"
    s = dashboards.queue_summary(
        [NOW - timedelta(hours=1), NOW + timedelta(minutes=5), NOW + timedelta(hours=9)], now=NOW
    )
    assert s == {"open": 3, "overdue": 1, "soon": 1}


# ---------------------------------------------------------------- funnel
def _cohort(n=6):
    """n verified live members registered 'now'."""
    return ids(members(n))


def test_funnel_counts_a_cohort_and_suppresses_small_cells():
    from mc.accounts import selectors as accounts
    from mc.entitlements import selectors as ents
    from mc.interests import selectors as interests
    from mc.matches import selectors as matches
    from mc.profiles import selectors as profiles
    from mc.verification import selectors as verification

    cohort = _cohort(6)
    start, end = timezone.now() - timedelta(days=1), timezone.now() + timedelta(days=1)
    kw = {"start": start, "end": end}
    assert accounts.funnel_registered_count(**kw) == 6
    assert verification.funnel_verified_count(**kw) == 6
    assert profiles.funnel_live_count(**kw) == 6
    # 4 senders -> suppressed; 5 -> shown
    for sender in cohort[:4]:
        Interest.objects.create(
            sender=sender, recipient=cohort[5], idempotency_key=uuid.uuid4().hex, expires_at=NOW
        )
    assert interests.funnel_first_interest_count(**kw) is None
    Interest.objects.create(
        sender=cohort[4], recipient=cohort[5], idempotency_key=uuid.uuid4().hex, expires_at=NOW
    )
    assert interests.funnel_first_interest_count(**kw) == 5
    # a repeat sender is one member, not two
    Interest.objects.create(
        sender=cohort[0], recipient=cohort[4], idempotency_key=uuid.uuid4().hex, expires_at=NOW
    )
    assert interests.funnel_first_interest_count(**kw) == 5
    # matches count both members once: 3 matches over 6 accounts
    for a, b in ((0, 1), (2, 3), (4, 5)):
        x, y = sorted((cohort[a].id, cohort[b].id))
        Match.objects.create(user_a_id=x, user_b_id=y)
    assert matches.funnel_first_match_count(**kw) == 6
    # a second match for the same person doesn't change the count
    Match.objects.create(
        user_a_id=sorted((cohort[0].id, cohort[2].id))[0],
        user_b_id=sorted((cohort[0].id, cohort[2].id))[1],
        status="unmatched",
    )
    assert matches.funnel_first_match_count(**kw) == 6
    # members: purchases only, not trials/grants, not refunded
    for i, acct in enumerate(cohort[:6]):
        Entitlement.objects.create(
            account=acct,
            source="purchase" if i < 5 else "trial",
            starts_at=NOW,
            ends_at=NOW + timedelta(days=30),
        )
    assert ents.funnel_member_count(**kw) == 5
    Entitlement.objects.filter(account=cohort[0]).update(revoked_at=NOW)
    assert ents.funnel_member_count(**kw) is None  # 4 left -> suppressed


def test_funnel_is_a_cohort_by_registration_date():
    from mc.accounts import selectors as accounts

    cohort = _cohort(6)
    Account.objects.filter(id__in=[a.id for a in cohort[:2]]).update(
        created_at=timezone.now() - timedelta(days=90)
    )
    now = timezone.now()
    assert (
        accounts.funnel_registered_count(start=now - timedelta(days=1), end=now + timedelta(days=1))
        is None
    )  # 4
    assert (
        accounts.funnel_registered_count(
            start=now - timedelta(days=100), end=now + timedelta(days=1)
        )
        == 6
    )


def test_funnel_page_shows_totals_hides_small_cells_and_exposes_no_member_data():
    cohort = _cohort(6)
    for sender in cohort[:3]:
        Interest.objects.create(
            sender=sender, recipient=cohort[5], idempotency_key=uuid.uuid4().hex, expires_at=NOW
        )
    c = full_login(staff(["payments_ops"]))
    r = c.get("/dashboards/funnel")
    page = r.content.decode()
    assert r.status_code == 200
    rows = {x["key"]: x for x in r.context["rows"]}
    assert rows["registered"]["count"] == 6 and rows["verified"]["text"] == "6"
    assert rows["first_interest"]["count"] is None and rows["first_interest"]["text"] == "<5"
    assert rows["first_interest"]["of_registered"] is None  # no ratio from a hidden cell
    assert rows["verified"]["of_registered"] == "100%"
    assert rows["member"]["text"] == "<5"
    for a in cohort:
        assert str(a.id) not in page and a.phone_e164 not in page
    for p in Profile.objects.all():
        assert p.display_name not in page or p.display_name == ""


def test_funnel_page_range_validation_and_default():
    c = full_login(staff(["privacy_officer"]))
    ok = c.get("/dashboards/funnel", {"from": "2026-01-01", "to": "2026-01-31"})
    assert ok.status_code == 200 and ok.context["rng"].first == date(2026, 1, 1)
    bad = c.get("/dashboards/funnel", {"from": "garbage", "to": "2026-01-31"})
    assert bad.status_code == 200 and "Dates must look like" in bad.content.decode()
    too_long = c.get("/dashboards/funnel", {"from": "2020-01-01", "to": "2026-01-31"})
    assert "at most 366 days" in too_long.content.decode()
    # SQL-ish / oversized input is just a bad date
    assert (
        c.get("/dashboards/funnel", {"from": "1; DROP TABLE x", "to": "x" * 5000}).status_code
        == 200
    )


def test_funnel_page_rejects_non_get_methods_safely():
    c = full_login(staff(["payments_ops"]))
    assert c.post("/dashboards/funnel").status_code in (200, 405)  # read-only; nothing is written
    assert not AuditEvent.objects.filter(action__startswith="funnel.").exists()


# ---------------------------------------------------------------- density
def test_density_counts_live_profiles_per_district_and_suppresses_small_cells():
    from mc.profiles import selectors as profiles

    members(5, district="Kampala")
    members(4, district="Gulu")
    members(1, district="Mbale", live=False)  # draft: not counted
    rows = {r["district"]: r["live"] for r in profiles.live_density_by_district()}
    assert (
        rows["Kampala"] == 5
        and rows["Gulu"] is None
        and rows["Mbale"] is None
        and rows["Arua"] is None
    )
    # hidden-by-member is not "live now"
    Profile.objects.filter(
        account=Account.objects.filter(profile__district="Kampala").first()
    ).update(status="hidden_by_user")
    assert {r["district"]: r["live"] for r in profiles.live_density_by_district()}[
        "Kampala"
    ] is None


def test_density_orders_largest_first_and_includes_abroad():
    from mc.profiles import selectors as profiles

    members(7, district="Wakiso")
    members(5, district="Kampala")
    members(6, district="abroad", diaspora_country="GB")
    order = [r["district"] for r in profiles.live_density_by_district() if r["live"] is not None]
    assert order == ["Wakiso", "abroad", "Kampala"]


def test_density_page_shows_labels_and_no_member_data_or_unsuppressed_total():
    batch = members(5, district="Kampala") + members(3, district="Gulu")
    c = full_login(staff(["trust_safety"]))
    r = c.get("/dashboards/density")
    page = r.content.decode()
    assert r.status_code == 200 and r.context["shown_total"] == 5
    assert r.context["hidden_cells"] == len(r.context["rows"]) - 1
    assert "<5" in page or "&lt;5" in page
    assert "Gulu" in page
    for a in batch:
        assert str(a.id) not in page and a.phone_e164 not in page


# ---------------------------------------------------------------- payments reconciliation
def _report(mismatches=(), at=None, **kw):
    return {
        "generated_at": (at or timezone.now()).isoformat(), "window_hours": 48, "purchases_active": 7,
        "events_received": 12, "mismatches": list(mismatches), **kw,
    }  # fmt: skip


def test_nightly_task_persists_the_report_for_the_portal():
    from mc.billing import tasks

    tasks.nightly_reconciliation()
    row = recon_reports.latest()
    assert row is not None and row.mismatch_count == 0 and row.window_hours == 48


def test_reconciliation_page_shows_latest_report_with_mismatches_and_history():
    pid, eid = str(uuid.uuid4()), str(uuid.uuid4())
    recon_reports.save_report(_report(at=timezone.now() - timedelta(days=1)))
    recon_reports.save_report(
        _report(
            [
                {"purchase": pid, "problem": "pending_over_24h"},
                {"event": eid, "problem": "failed_event:account_unresolved"},
            ]
        )
    )
    for role in ("payments_ops", "privacy_officer"):
        r = full_login(staff([role], email=f"{role}@marriageconnect.ug")).get(
            "/payments/reconciliation"
        )
        page = r.content.decode()
        assert r.status_code == 200 and not r.context["stale"]
        assert pid in page and eid in page and "pending_over_24h" in page
        assert "2 mismatches" in page and len(r.context["history"]) == 2


def test_reconciliation_page_flags_missing_or_stale_runs():
    c = full_login(staff(["payments_ops"]))
    r = c.get("/payments/reconciliation")
    assert (
        r.status_code == 200
        and r.context["stale"]
        and "No nightly reconciliation has run yet" in r.content.decode()
    )
    recon_reports.save_report(_report(at=timezone.now() - timedelta(hours=40)))
    r = c.get("/payments/reconciliation")
    assert r.context["stale"] and "has not run for over 36 hours" in r.content.decode()
    recon_reports.save_report(_report(at=timezone.now() - timedelta(hours=35)))
    assert not c.get("/payments/reconciliation").context["stale"]


def test_report_retention_and_mismatch_cap(settings):
    for i in range(recon_reports.KEEP + 3):
        recon_reports.save_report(_report(at=timezone.now() - timedelta(hours=i)))
    assert ReconciliationReport.objects.count() == recon_reports.KEEP
    big = [{"purchase": str(uuid.uuid4()), "problem": "pending_over_24h"}] * (
        recon_reports.MAX_STORED_MISMATCHES + 20
    )
    row = recon_reports.save_report(_report(big))
    assert (
        row.mismatch_count == len(big)
        and len(row.mismatches) == recon_reports.MAX_STORED_MISMATCHES
    )
    page = full_login(staff(["payments_ops"])).get("/payments/reconciliation").content.decode()
    assert f"Showing the first {recon_reports.MAX_STORED_MISMATCHES} of {len(big)}" in page


def test_reconciliation_service_rechecks_the_role():
    for role in ("support", "trust_safety", "engineer_oncall", "verification_reviewer", ""):
        with pytest.raises(Forbidden):
            admin_ops.reconciliation_overview(actor_id=uuid.uuid4(), role=role)
    assert (
        admin_ops.reconciliation_overview(actor_id=uuid.uuid4(), role="payments_ops")["latest"]
        is None
    )


# ---------------------------------------------------------------- queues with SLA timers
def test_verification_queue_shows_due_in_and_overdue_badges():
    from mc.verification.models import VerificationAttempt
    from mc.verification.tests.helpers import callback, job_id_of, new_user, result, start

    for phone in ("+256772700101", "+256772700102"):
        c0, r0 = new_user(phone)
        callback(c0, result(job_id_of(start(c0, r0)), outcome="needs_review"))
    old, fresh = VerificationAttempt.objects.order_by("id")
    VerificationAttempt.objects.filter(id=old.id).update(
        created_at=timezone.now() - timedelta(hours=30)
    )
    r = full_login(staff(["verification_reviewer"])).get("/verification")
    page = r.content.decode()
    assert r.status_code == 200
    assert "Overdue by 6h" in page and "badge overdue" in page
    assert "Due in 23h" in page and "badge ok" in page
    assert r.context["summary"] == {"open": 2, "overdue": 1, "soon": 0}
    due = {x["attempt_id"]: x["due_at"] for x in r.context["rows"]}
    old.refresh_from_db()
    assert due[str(old.id)] == old.created_at + timedelta(hours=24)


def test_verification_sla_is_configurable(settings):
    from mc.verification import review
    from mc.verification.models import VerificationAttempt
    from mc.verification.tests.helpers import callback, job_id_of, new_user, result, start

    settings.VERIFICATION_REVIEW_SLA_HOURS = 2
    c0, r0 = new_user("+256772700103")
    callback(c0, result(job_id_of(start(c0, r0)), outcome="needs_review"))
    a = VerificationAttempt.objects.get()
    row = review.queue(actor_id=uuid.uuid4(), role="verification_reviewer")[0]
    assert row["due_at"] == a.created_at + timedelta(hours=2)


def test_moderation_queue_shows_sla_timers_by_severity():
    from mc.interests.tests.helpers import pair
    from mc.safety.models import Case
    from mc.safety.tests.test_enforcement import report_case

    m, f = pair()
    case = report_case(m, f)
    Case.objects.filter(id=case.id).update(
        sla_due_at=timezone.now() - timedelta(minutes=90), severity="s1"
    )
    m2, f2 = pair()
    c2 = report_case(m2, f2, category="spam")
    Case.objects.filter(id=c2.id).update(sla_due_at=timezone.now() + timedelta(hours=30))
    r = full_login(staff(["trust_safety"])).get("/safety")
    page = r.content.decode()
    assert "Overdue by 1h 29m" in page or "Overdue by 1h 30m" in page
    assert "badge overdue" in page and "badge ok" in page
    assert r.context["summary"]["open"] == 2 and r.context["summary"]["overdue"] == 1


# ---------------------------------------------------------------- feature flags page
def _stale_reauth():
    StaffSession.objects.update(reauth_at=timezone.now() - timedelta(hours=2))


def test_flags_page_lists_flags_with_source_and_lock():
    c = full_login(staff(["engineer_oncall"]))
    r = c.get("/flags")
    by = {f["key"]: f for f in r.context["rows"]}
    assert r.status_code == 200
    assert by["voice_notes"]["enabled"] and by["voice_notes"]["source"] == "default"
    assert by["phase5_disclosure"]["locked"] and not by["phase5_disclosure"]["enabled"]
    assert "ranking_model_v2" in by


def test_flag_change_needs_step_up_then_works_audited_and_takes_effect_immediately():
    from django.test import Client

    s = staff(["engineer_oncall"])
    c = full_login(s)
    api = Client(headers={"host": "api.mc.test"})
    assert api.get("/api/v1/config/flags").json()["flags"]["voice_notes"] is True  # cached now
    _stale_reauth()
    r = c.post("/flags", {"key": "voice_notes", "value": "off", "reason": "incident"})
    assert r.status_code == 302 and "/stepup" in r["Location"]
    assert not FeatureFlag.objects.exists()
    assert c.post("/stepup?next=/flags", {"code": next_code(s)}).status_code == 302
    r = c.post("/flags", {"key": "voice_notes", "value": "off", "reason": "incident 7"})
    assert r.status_code == 200 and "Saved." in r.content.decode()
    ev = AuditEvent.objects.get(action="config.flag_set")
    assert ev.actor_id == s.id and ev.role == "engineer_oncall" and ev.reason == "incident 7"
    assert ev.metadata == {"key": "voice_notes", "from": True, "to": False}
    assert (
        api.get("/api/v1/config/flags").json()["flags"]["voice_notes"] is False
    )  # cache invalidated
    again = c.post("/flags", {"key": "voice_notes", "value": "off", "reason": "again"})
    assert (
        "No change" in again.content.decode()
        and AuditEvent.objects.filter(action="config.flag_set").count() == 1
    )


def test_flag_change_validation_messages():
    c = full_login(staff(["superadmin"]))
    page = lambda **d: c.post("/flags", d).content.decode()  # noqa: E731
    assert "A reason is required" in page(key="voice_notes", value="off", reason=" ")
    assert "Choose on or off" in page(key="voice_notes", value="maybe", reason="x")
    assert "Choose on or off" in page(key="voice_notes", reason="x")
    assert "Unknown feature flag" in page(key="typo", value="on", reason="x")
    assert "not built yet" in page(key="phase5_counselling", value="on", reason="x")
    assert (
        not FeatureFlag.objects.exists()
        and not AuditEvent.objects.filter(action="config.flag_set").exists()
    )


def test_flag_changes_are_denied_for_every_other_role_scenario_12(caplog):
    import logging

    for role in (
        "support",
        "trust_safety",
        "payments_ops",
        "privacy_officer",
        "verification_reviewer",
    ):
        s = staff([role], email=f"{role}@marriageconnect.ug")
        c = full_login(s)
        with caplog.at_level(logging.WARNING, logger="mc.adminportal"):
            assert c.get("/flags").status_code == 403
            assert (
                c.post(
                    "/flags", {"key": "voice_notes", "value": "off", "reason": "sneaky"}
                ).status_code
                == 403
            )
        assert (
            AuditEvent.objects.filter(
                action="admin.denied", actor_id=s.id, reason__startswith="config.flags"
            ).count()
            == 2
        )
    assert not FeatureFlag.objects.exists()
    assert [r for r in caplog.records if getattr(r, "alert", "") == "admin_access_denied"]


def test_flags_post_is_csrf_protected():
    from django.test import Client

    from mc.adminportal.tests.helpers import HOST

    c = full_login(staff(["engineer_oncall"]))
    strict = Client(headers={"host": HOST}, enforce_csrf_checks=True)
    strict.cookies = c.cookies
    assert (
        strict.post("/flags", {"key": "voice_notes", "value": "off", "reason": "x"}).status_code
        == 403
    )
    assert not FeatureFlag.objects.exists()


def test_flag_change_does_not_leak_into_logs(caplog):
    import logging

    c = full_login(staff(["engineer_oncall"]))
    with caplog.at_level(logging.DEBUG):
        c.post(
            "/flags", {"key": "voice_notes", "value": "off", "reason": "contains secret-note-123"}
        )
    assert "secret-note-123" not in caplog.text


def test_portal_pages_are_not_served_on_the_public_api_host():
    from django.test import Client

    api = Client(headers={"host": "api.mc.test"})
    for path in ("/flags", "/dashboards/funnel", "/dashboards/density", "/payments/reconciliation"):
        assert api.get(path).status_code == 404, path

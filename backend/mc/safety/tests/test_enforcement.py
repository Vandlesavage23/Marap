import uuid
from datetime import timedelta

import pytest
from django.test import Client
from django.utils import timezone
from freezegun import freeze_time

from mc.accounts.models import Account, Session
from mc.accounts.tests.helpers import bearer, login
from mc.audit.models import AuditEvent
from mc.interests.tests.helpers import member, pair, send
from mc.matches.models import Match
from mc.messaging.models import Message
from mc.messaging.tests.helpers import matched, say
from mc.notifications.models import Notification
from mc.profiles.models import Profile
from mc.safety import enforcement, selectors
from mc.safety.models import Action, Ban, Case, Report
from mc.verification.tests.helpers import J, callback, job_id_of, new_user, result, start

pytestmark = pytest.mark.django_db
STAFF = uuid.uuid4()
OTHER_STAFF = uuid.uuid4()


def act(subject, kind, **kw):
    return enforcement.take_action(
        subject_id=subject.id, kind=kind, actor_id=kw.pop("actor_id", STAFF), actor_role="trust_safety",
        reason=kw.pop("reason", "policy violation"), **kw,
    )  # fmt: skip


def report_case(m, f, category="harassment", context_type="profile", context_id=None):
    body = {"profile_id": f[3], "category": category, "context_type": context_type}
    if context_id:
        body["context_id"] = context_id
    m[0].post("/api/v1/reports", body, **bearer(m[1]), HTTP_IDEMPOTENCY_KEY=uuid.uuid4().hex, **J)
    return Case.objects.get(subject=f[2], status="open")


def test_every_action_requires_a_reason_and_is_audited():
    m, f = pair()
    from mc.common.errors import ValidationFailed

    with pytest.raises(ValidationFailed):
        act(f[2], "warn", reason=" ")
    with pytest.raises(ValidationFailed):
        act(f[2], "explode")
    for kind in ("warn", "suspend_7d", "reinstate", "ban"):
        act(f[2], kind, reason=f"because {kind}")
    events = AuditEvent.objects.filter(action__startswith="safety.")
    assert {e.action for e in events} == {
        "safety.warn",
        "safety.suspend_7d",
        "safety.reinstate",
        "safety.ban",
    }
    assert all(
        e.actor_id == STAFF and e.role == "trust_safety" and e.target_id == f[2].id and e.reason
        for e in events
    )
    assert "body" not in str([e.metadata for e in events])  # no PII in audit metadata


def test_warn_notifies_with_generic_text():
    m, f = pair()
    act(f[2], "warn")
    n = Notification.objects.get(account=f[2])
    assert n.type == "warning" and set(n.payload) == {"action_id"}


def test_suspend_signs_out_hides_profile_and_blocks_features_but_allows_appeal_path():
    m, f = pair()
    token = f[1].json()["access"]
    action = act(f[2], "suspend_7d")
    assert Account.objects.get(id=f[2].id).status == "suspended"
    assert Profile.objects.get(account=f[2]).status == "suspended"
    assert not Session.objects.filter(account=f[2], revoked_at__isnull=True).exists()
    assert (
        f[0].get("/api/v1/me", HTTP_AUTHORIZATION=f"Bearer {token}").status_code == 401
    )  # logged out
    # they can sign in again (OTP) to see the decision...
    c = Client(headers={"host": "api.mc.test"})
    r = login(c, phone=f[2].phone_e164)
    me = c.get("/api/v1/me", **bearer(r))
    assert me.status_code == 200 and me.json()["status"] == "suspended"
    enf = me.json()["enforcement"]
    assert (
        enf["action_id"] == str(action.id)
        and enf["kind"] == "suspend_7d"
        and enf["appeal_available"] is True
    )
    assert "reason" not in str(enf) and "policy violation" not in str(me.json())
    # ...but no member feature works
    for path in (
        "/api/v1/discovery",
        "/api/v1/matches",
        "/api/v1/me/profile",
        "/api/v1/interests/received",
        "/api/v1/me/entitlements",
    ):
        resp = c.get(path, **bearer(r))
        assert resp.status_code == 403 and resp.json()["code"] == "forbidden", path
    assert (
        c.post("/api/v1/auth/logout", **bearer(r)).status_code == 204
    )  # account controls still work
    # and they vanish for others
    assert f[0] is not None and str(f[2].id) not in {
        e.account_id
        for e in __import__("mc.discovery.services", fromlist=["x"]).build_ranked_pool(m[2])[0]
    }


def test_suspension_expires_and_reinstates_automatically():
    m, f = pair()
    with freeze_time(timezone.now()) as t:
        act(f[2], "suspend_7d")
        assert enforcement.lift_expired_suspensions() == 0
        t.tick(timedelta(days=6, hours=23))
        assert enforcement.lift_expired_suspensions() == 0
        t.tick(timedelta(hours=2))
        assert enforcement.lift_expired_suspensions() == 1
        assert enforcement.lift_expired_suspensions() == 0  # idempotent
    assert Account.objects.get(id=f[2].id).status == "active"
    assert Profile.objects.get(account=f[2]).status == "live"
    assert (
        AuditEvent.objects.filter(action="safety.suspension_expired", actor_type="system").count()
        == 1
    )
    from mc.safety import tasks

    assert tasks.lift_expired_suspensions() == 0


def test_ban_is_permanent_and_blocks_the_same_person_on_a_new_phone():
    # a real verified identity gets banned...
    c, r = new_user("+256772300001")
    callback(c, result(job_id_of(start(c, r)), id_number="BAN-ME-123"))
    acct = Account.objects.get(phone_e164="+256772300001")
    act(acct, "ban")
    assert Ban.objects.count() == 1 and enforcement.lift_expired_suspensions() == 0
    from datetime import datetime

    with freeze_time(datetime.now() + timedelta(days=30)):
        enforcement.lift_expired_suspensions()
    assert Account.objects.get(id=acct.id).status == "suspended"  # bans never expire
    # ...and tries again with another phone and the same ID number
    c2, r2 = new_user("+256772300002")
    callback(c2, result(job_id_of(start(c2, r2)), id_number="ban me 123"))
    from mc.verification.models import VerificationAttempt

    att = VerificationAttempt.objects.get(account__phone_e164="+256772300002")
    assert (att.status, att.reason_code) == ("failed", "banned")
    assert selectors.is_identity_banned(
        bytes(VerificationAttempt.objects.get(account=acct).id_number_hmac)
    )
    from mc.verification import reasons

    assert reasons.BANNED in reasons.NO_APPEAL


def test_reinstate_lifts_ban_and_restores_profile():
    m, f = pair()
    act(f[2], "ban")
    assert Profile.objects.get(account=f[2]).status == "suspended"
    act(f[2], "reinstate", reason="appeal upheld")
    assert Account.objects.get(id=f[2].id).status == "active"
    assert Profile.objects.get(account=f[2]).status == "live"
    assert (
        not Ban.objects.exists()
        and not Action.objects.filter(
            kind__in=["ban", "suspend_7d"], lifted_at__isnull=True
        ).exists()
    )


def test_hide_content_requires_report_and_hides_a_message_for_both():
    m, f, mid = matched()
    Match.objects.update(created_at=timezone.now() - timedelta(days=10))
    bad = say(f, mid, "abusive words").json()["id"]
    case = report_case(m, f, "harassment", "message", bad)
    from mc.common.errors import ValidationFailed

    with pytest.raises(ValidationFailed):
        act(f[2], "hide_content", case_id=case.id)
    report = Report.objects.get()
    act(f[2], "hide_content", case_id=case.id, report_id=report.id)
    assert Message.objects.get(id=bad).deleted_placeholder is True
    from mc.messaging.tests.helpers import history

    items = {i["id"]: i for i in history(m, mid).json()["items"]}
    assert items[bad]["deleted"] is True and items[bad]["body"] is None
    assert Report.objects.get().status == "actioned"


def test_hide_content_for_interest_and_profile_contexts():
    m, f = pair()
    iid = send(f[0], f[1], m[3]).json()["id"]
    case = report_case(m, f, "sexual_content", "interest", iid)
    act(f[2], "hide_content", case_id=case.id, report_id=Report.objects.get().id)
    from mc.interests.models import Interest

    assert Interest.objects.get(id=iid).status == "cancelled"
    m2, f2 = pair()
    case2 = report_case(m2, f2, "fake_profile")
    act(f2[2], "hide_content", case_id=case2.id, report_id=Report.objects.get(subject=f2[2]).id)
    assert Profile.objects.get(account=f2[2]).status == "suspended"


def test_case_can_be_closed_with_resolution():
    m, f = pair()
    case = report_case(m, f)
    act(f[2], "warn", case_id=case.id, close_case=True)
    case.refresh_from_db()
    assert case.status == "closed" and case.resolution == "warn" and case.closed_at
    assert not selectors.open_cases().exists()
    # a later report opens a fresh case
    report_case(m, f, "spam")
    assert Case.objects.filter(subject=f[2]).count() == 2


# ---- appeals (MC-088) -----------------------------------------------------------------------------
def appeal(c, r, action_id, message="I did nothing wrong, please check again."):
    return c.post(
        "/api/v1/safety/appeals",
        {"action_id": str(action_id), "message": message},
        **bearer(r),
        **J,
    )


def suspended_member():
    m, f = pair()
    action = act(f[2], "suspend_7d")
    c = Client(headers={"host": "api.mc.test"})
    r = login(c, phone=f[2].phone_e164)
    return c, r, f[2], action


def test_one_appeal_per_action():
    c, r, acct, action = suspended_member()
    first = appeal(c, r, action.id)
    assert first.status_code == 201 and first.json()["status"] == "open"
    second = appeal(c, r, action.id)
    assert second.status_code == 409 and second.json()["code"] == "conflict"
    assert c.get("/api/v1/me", **bearer(r)).json()["enforcement"]["appeal_available"] is False
    assert appeal(c, r, action.id, "short").status_code in (409, 422)


def test_appeal_validation_and_ownership():
    c, r, acct, action = suspended_member()
    assert appeal(c, r, action.id, "too short").status_code == 422
    assert appeal(c, r, uuid.uuid4()).status_code == 404
    other = member("male")
    assert appeal(other[0], other[1], action.id).status_code == 404  # someone else's action
    reinstate = act(acct, "reinstate")
    assert appeal(c, r, reinstate.id).status_code == 404
    assert (
        Client(headers={"host": "api.mc.test"}).post("/api/v1/safety/appeals", {}, **J).status_code
        == 401
    )


def test_different_reviewer_enforced_and_upheld_appeal_reinstates():
    c, r, acct, action = suspended_member()
    ap = appeal(c, r, action.id).json()["id"]
    from mc.common.errors import Forbidden, ValidationFailed

    with pytest.raises(Forbidden):
        enforcement.decide_appeal(
            appeal_id=ap,
            reviewer_id=STAFF,
            reviewer_role="trust_safety",
            uphold=True,
            reason="same person",
        )
    with pytest.raises(ValidationFailed):
        enforcement.decide_appeal(
            appeal_id=ap,
            reviewer_id=OTHER_STAFF,
            reviewer_role="trust_safety",
            uphold=True,
            reason=" ",
        )
    done = enforcement.decide_appeal(
        appeal_id=ap,
        reviewer_id=OTHER_STAFF,
        reviewer_role="trust_safety",
        uphold=True,
        reason="evidence insufficient",
    )
    assert done.status == "upheld" and done.decided_by == OTHER_STAFF
    assert (
        Account.objects.get(id=acct.id).status == "active"
        and Profile.objects.get(account=acct).status == "live"
    )
    assert Notification.objects.filter(
        account=acct, type="appeal_decided", payload__upheld="true"
    ).exists()
    assert AuditEvent.objects.filter(action="safety.appeal_decided", actor_id=OTHER_STAFF).exists()
    with pytest.raises(Exception):  # noqa: B017 - already decided → Conflict
        enforcement.decide_appeal(
            appeal_id=ap,
            reviewer_id=OTHER_STAFF,
            reviewer_role="trust_safety",
            uphold=False,
            reason="again",
        )


def test_rejected_appeal_keeps_restriction():
    c, r, acct, action = suspended_member()
    ap = appeal(c, r, action.id).json()["id"]
    done = enforcement.decide_appeal(
        appeal_id=ap,
        reviewer_id=OTHER_STAFF,
        reviewer_role="trust_safety",
        uphold=False,
        reason="violation confirmed",
    )
    assert done.status == "rejected" and Account.objects.get(id=acct.id).status == "suspended"
    assert Notification.objects.filter(
        account=acct, type="appeal_decided", payload__upheld="false"
    ).exists()


def test_websocket_refused_for_suspended_members():
    from mc.accounts import selectors as account_selectors
    from mc.common.errors import Unauthenticated

    c, r, acct, action = suspended_member()
    with pytest.raises(Unauthenticated):
        account_selectors.authenticate_access_token(r.json()["access"])

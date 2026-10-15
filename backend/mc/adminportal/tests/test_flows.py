import pytest

from mc.accounts.models import Account
from mc.adminportal.tests.helpers import full_login, next_code, staff
from mc.audit.models import AuditEvent
from mc.interests.tests.helpers import pair
from mc.privacy.models import PrivacyRequest
from mc.safety.models import Case
from mc.safety.tests.test_enforcement import report_case
from mc.verification.models import VerificationAttempt
from mc.verification.tests.helpers import callback, job_id_of, new_user, result, start

pytestmark = pytest.mark.django_db


def _stepped(s):
    c = full_login(s)
    return c


def test_verification_review_through_the_portal():
    c0, r0 = new_user("+256772700001")
    callback(c0, result(job_id_of(start(c0, r0)), outcome="needs_review"))
    a = VerificationAttempt.objects.get(account__phone_e164="+256772700001")
    s = staff(["verification_reviewer"])
    c = _stepped(s)
    assert str(a.id) in c.get("/verification").content.decode()
    assert (
        "Claimed"
        in c.post("/verification", {"attempt": str(a.id), "action": "claim"}).content.decode()
    )
    r = c.post("/verification", {"attempt": str(a.id), "action": "approve", "reason": "ID matches"})
    assert "Decision saved" in r.content.decode()
    a.refresh_from_db()
    assert a.status == "passed" and a.reviewed_by == s.id
    assert AuditEvent.objects.filter(action="verification.review", actor_id=s.id).exists()


def test_support_cannot_decide_verification_or_see_the_queue():
    c = _stepped(staff(["support"]))
    assert c.get("/verification").status_code == 403
    assert c.post("/verification", {"attempt": "x", "action": "approve"}).status_code == 403


def test_moderator_acts_on_a_case_with_evidence_and_it_is_audited():
    m, f = pair()
    case = report_case(m, f)
    s = staff(["trust_safety"])
    c = _stepped(s)
    assert str(case.id) in c.get("/safety").content.decode()
    page = c.get(f"/safety/{case.id}")
    assert page.status_code == 200 and "harassment" in page.content.decode()
    assert AuditEvent.objects.filter(action="admin.view_evidence", target_id=case.id).exists()
    r = c.post(f"/safety/{case.id}/act", {"kind": "warn", "reason": "first warning", "close": "1"})
    assert "Action applied" in r.content.decode() or r.status_code == 302
    case.refresh_from_db()
    assert AuditEvent.objects.filter(action="safety.warn", actor_id=s.id).exists()


def test_safety_act_requires_step_up_and_a_reason():
    m, f = pair()
    case = report_case(m, f)
    s = staff(["trust_safety"])
    c = _stepped(s)
    from datetime import timedelta

    from django.utils import timezone

    from mc.adminportal.models import StaffSession

    StaffSession.objects.update(reauth_at=timezone.now() - timedelta(hours=1))
    r = c.post(f"/safety/{case.id}/act", {"kind": "ban", "reason": "x"})
    assert r.status_code == 302 and "/stepup" in r["Location"]
    c.post("/stepup", {"code": next_code(s)})
    r = c.post(f"/safety/{case.id}/act", {"kind": "ban", "reason": " "})
    assert "reason" in r.content.decode().lower()
    assert Case.objects.get(id=case.id).status == "open"
    assert Account.objects.get(id=f[2].id).status == "active"


def test_payments_ops_sees_purchases_audited_and_privacy_officer_restores_deletion():
    m, _ = pair()
    c = _stepped(staff(["payments_ops"]))
    assert c.get("/payments", {"account": str(m[2].id)}).status_code == 200
    assert AuditEvent.objects.filter(target_id=m[2].id, action="admin.view").exists()
    assert c.get("/privacy").status_code == 403

    s = staff(["privacy_officer"], email="priv@marriageconnect.ug")
    c = _stepped(s)
    from django.utils import timezone

    from mc.accounts import services as account_services

    account_services.set_status(account=m[2], status="deactivated")
    PrivacyRequest.objects.create(
        account=m[2],
        account_ref=m[2].id,
        kind="delete",
        requested_at=timezone.now(),
        due_at=timezone.now(),
    )
    assert str(m[2].id) in c.get("/privacy").content.decode()
    assert "Deletion cancelled" in c.post("/privacy", {"account": str(m[2].id)}).content.decode()
    assert AuditEvent.objects.filter(action="privacy.deletion_cancelled", actor_id=s.id).exists()


def test_support_notes_are_audited_encrypted_and_erased_with_the_account(s3):
    from django.db import connection

    from mc.adminportal.models import SupportNote
    from mc.privacy import services as privacy_services

    m, _ = pair()
    s = staff(["support"])
    c = _stepped(s)
    r = c.post(f"/users/{m[2].id}/notes", {"body": "Called member, resolved login issue"})
    assert "Note saved" in r.content.decode()
    assert "resolved login issue" in c.get("/users", {"q": str(m[2].id)}).content.decode()
    with connection.cursor() as cur:
        cur.execute("SELECT body FROM adminportal_supportnote")
        assert cur.fetchone()[0].startswith("v1:")
    assert AuditEvent.objects.filter(action="support.note_added", actor_id=s.id).exists()
    assert "3-1,000" in c.post(f"/users/{m[2].id}/notes", {"body": "x"}).content.decode()
    privacy_services._erase(m[2])
    assert not SupportNote.objects.exists()


def test_support_can_see_status_and_entitlement_but_not_special_data_or_chats():
    m, _ = pair()
    c = _stepped(staff(["support"]))
    body = c.get("/users", {"q": str(m[2].id)}).content.decode()
    for needle in ("Verification", "Access", "Live sessions"):
        assert needle in body
    for forbidden in ("answers", "religion", m[2].phone_e164):
        assert forbidden not in body.lower()

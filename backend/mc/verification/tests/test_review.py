import uuid
from datetime import date

import pytest

from mc.accounts.models import Account
from mc.accounts.tests.helpers import bearer
from mc.audit.models import AuditEvent
from mc.common.errors import Conflict, Forbidden, NotFound, ValidationFailed
from mc.notifications.models import Notification
from mc.verification import review
from mc.verification.models import VerificationAppeal, VerificationAttempt

from .helpers import J, callback, job_id_of, new_user, result, start

pytestmark = pytest.mark.django_db
R1, R2 = uuid.uuid4(), uuid.uuid4()


def needs_review(phone="+256772600001", **kw):
    c, r = new_user(phone)
    callback(c, result(job_id_of(start(c, r)), outcome="needs_review", **kw))
    return c, r, VerificationAttempt.objects.get(account__phone_e164=phone)


def failed_attempt(phone="+256772600002", reason="face_mismatch"):
    c, r = new_user(phone)
    callback(
        c,
        result(
            job_id_of(start(c, r)),
            outcome="failed",
            vendor_reason=reason,
            id_number=None,
            date_of_birth=None,
        ),
    )
    return c, r, VerificationAttempt.objects.get(account__phone_e164=phone)


def decide(
    a, approve=True, who=R1, role="verification_reviewer", reason="documents look fine", **kw
):
    return review.decide_review(
        attempt_id=a.id, actor_id=who, role=role, approve=approve, reason=reason, **kw
    )


def test_queue_roles_summary_and_no_images():
    c, r, a = needs_review()
    assert (
        a.date_of_birth and a.id_number_hmac
    )  # kept for the human decision; never the ID number itself
    for role in ("support", "trust_safety", "payments_ops", "engineer_oncall", "member"):
        with pytest.raises(Forbidden):
            review.queue(actor_id=R1, role=role)
    q = review.queue(actor_id=R1, role="verification_reviewer")
    assert [x["attempt_id"] for x in q] == [str(a.id)] and q[0]["outcome"][
        "outcome"
    ] == "needs_review"
    assert "image" not in str(q).lower() and "9512" not in str(q)


def test_claiming_assigns_the_case_to_one_reviewer():
    c, r, a = needs_review()
    review.claim(attempt_id=a.id, actor_id=R1, role="verification_reviewer")
    assert VerificationAttempt.objects.get(id=a.id).reviewed_by == R1
    with pytest.raises(Conflict):
        review.claim(attempt_id=a.id, actor_id=R2, role="verification_reviewer")
    assert review.claim(
        attempt_id=a.id, actor_id=R1, role="verification_reviewer"
    )  # idempotent for the owner
    assert review.queue(actor_id=R2, role="verification_reviewer") == []  # assigned cases only
    assert len(review.queue(actor_id=R2, role="privacy_officer")) == 1
    with pytest.raises(NotFound):
        review.claim(attempt_id=uuid.uuid4(), actor_id=R1, role="verification_reviewer")


def test_must_claim_before_deciding_and_reason_required():
    c, r, a = needs_review()
    with pytest.raises(Forbidden):
        decide(a)
    review.claim(attempt_id=a.id, actor_id=R1, role="verification_reviewer")
    with pytest.raises(ValidationFailed):
        decide(a, reason=" ")
    with pytest.raises(Forbidden):
        decide(a, who=R2)
    with pytest.raises(Forbidden):
        decide(a, role="support")


def test_approve_passes_the_member_and_audits_and_notifies():
    c, r, a = needs_review()
    review.claim(attempt_id=a.id, actor_id=R1, role="verification_reviewer")
    out = decide(a)
    assert out.status == "passed" and out.decided_at and out.reviewed_by == R1
    assert Account.objects.get(phone_e164="+256772600001").status == "active"
    assert c.get("/api/v1/me", **bearer(r)).json()["verification_status"] == "passed"
    ev = AuditEvent.objects.get(action="verification.review")
    assert (
        ev.actor_id == R1
        and ev.metadata["outcome"] == "passed"
        and ev.reason == "documents look fine"
    )
    assert Notification.objects.get(type="verification_decided").payload == {"status": "passed"}
    with pytest.raises(NotFound):
        decide(a)  # already decided


def test_reject_fails_the_attempt_but_leaves_it_appealable():
    c, r, a = needs_review()
    review.claim(attempt_id=a.id, actor_id=R1, role="verification_reviewer")
    out = decide(a, approve=False, reason="photo doesn't match")
    assert (out.status, out.reason_code) == ("failed", "rejected_by_review")
    assert Account.objects.get(phone_e164="+256772600001").status == "pending_verification"


def test_approval_still_enforces_adult_duplicate_and_missing_data():
    # underage → fails + suspends + flags even though a human clicked approve
    c, r, a = needs_review(date_of_birth=date(2015, 1, 1))
    review.claim(attempt_id=a.id, actor_id=R1, role="verification_reviewer")
    out = decide(a)
    assert (out.status, out.reason_code, out.safety_flag) == ("failed", "underage", "underage")
    assert Account.objects.get(phone_e164="+256772600001").status == "suspended"
    # duplicate of an already verified identity
    c1, r1 = new_user("+256772600005")
    callback(c1, result(job_id_of(start(c1, r1)), id_number="DUP-1"))
    c2, r2, a2 = needs_review("+256772600006", id_number="dup 1")
    review.claim(attempt_id=a2.id, actor_id=R1, role="verification_reviewer")
    out2 = decide(a2)
    assert (out2.status, out2.reason_code) == ("failed", "duplicate_identity")
    # no dob / id on file → the reviewer must supply them
    c3, r3, a3 = needs_review("+256772600007", date_of_birth=None, id_number=None)
    review.claim(attempt_id=a3.id, actor_id=R1, role="verification_reviewer")
    with pytest.raises(ValidationFailed):
        decide(a3)
    ok = decide(a3, date_of_birth=date(1990, 3, 3), id_number="NEW-ID-777")
    assert ok.status == "passed"


def test_late_vendor_callback_cannot_override_a_review():
    c, r, a = needs_review()
    review.claim(attempt_id=a.id, actor_id=R1, role="verification_reviewer")
    decide(a, approve=False)
    callback(c, result(a.vendor_job_id))  # vendor now says "passed"
    assert VerificationAttempt.objects.get(id=a.id).status == "failed"


# ---- appeals ---------------------------------------------------------------------------------------
def appeal(c, r, attempt=None, message="The photo was blurry, please look again.", key=None):
    body = {"message": message, **({"attempt_id": str(attempt.id)} if attempt else {})}
    return c.post(
        "/api/v1/verification/appeals",
        body,
        **bearer(r),
        HTTP_IDEMPOTENCY_KEY=key or uuid.uuid4().hex,
        **J,
    )


def test_one_open_appeal_per_attempt_and_idempotent_retry():
    c, r, a = failed_attempt()
    first = appeal(c, r, key="appeal-key-12345")
    assert first.status_code == 201 and first.json()["status"] == "open"
    assert appeal(c, r, key="appeal-key-12345").json() == first.json()  # replay
    second = appeal(c, r)
    assert second.status_code == 409 and second.json()["code"] == "conflict"
    assert VerificationAppeal.objects.count() == 1


@pytest.mark.parametrize("reason", ["underage", "duplicate_identity", "banned"])
def test_support_only_reasons_cannot_be_appealed_in_app(reason):
    c, r, a = failed_attempt(reason="face_mismatch")
    VerificationAttempt.objects.filter(id=a.id).update(reason_code=reason)
    resp = appeal(c, r)
    assert resp.status_code == 403 and VerificationAppeal.objects.count() == 0


def test_appeal_validation_ownership_and_auth():
    from django.test import Client

    c, r, a = failed_attempt()
    assert appeal(c, r, message="too short").status_code == 422
    other_c, other_r, other_a = failed_attempt("+256772600009")
    assert appeal(other_c, other_r, a).status_code == 404  # someone else's attempt
    assert appeal(c, r, a).status_code == 201
    assert (
        Client(headers={"host": "api.mc.test"})
        .post("/api/v1/verification/appeals", {}, **J)
        .status_code
        == 401
    )
    c2, r2 = new_user("+256772600010")
    assert appeal(c2, r2).status_code == 404  # nothing failed to appeal


def test_upheld_appeal_verifies_with_reviewer_supplied_details():
    c, r, a = failed_attempt()
    ap = VerificationAppeal.objects.get(id=appeal(c, r).json()["id"])
    with pytest.raises(Forbidden):
        review.decide_appeal(appeal_id=ap.id, actor_id=R1, role="support", uphold=True, reason="x")
    with pytest.raises(ValidationFailed):  # nothing on file and none supplied
        review.decide_appeal(
            appeal_id=ap.id,
            actor_id=R1,
            role="verification_reviewer",
            uphold=True,
            reason="looks fine",
        )
    done = review.decide_appeal(
        appeal_id=ap.id,
        actor_id=R1,
        role="verification_reviewer",
        uphold=True,
        reason="checked manually",
        date_of_birth=date(1992, 2, 2),
        id_number="APPEAL-ID-1",
    )
    assert done.status == "upheld"
    assert VerificationAttempt.objects.get(id=a.id).status == "passed"
    assert Account.objects.get(phone_e164="+256772600002").status == "active"
    assert Notification.objects.filter(
        type="verification_decided", payload__appeal="true", payload__status="passed"
    ).exists()
    assert AuditEvent.objects.filter(action="verification.appeal_decided", actor_id=R1).exists()
    with pytest.raises(Conflict):
        review.decide_appeal(
            appeal_id=ap.id, actor_id=R1, role="verification_reviewer", uphold=False, reason="again"
        )


def test_rejected_appeal_keeps_failure_and_allows_nothing_further_for_that_attempt_until_new_one():
    c, r, a = failed_attempt()
    ap = VerificationAppeal.objects.get(id=appeal(c, r).json()["id"])
    review.decide_appeal(
        appeal_id=ap.id,
        actor_id=R1,
        role="verification_reviewer",
        uphold=False,
        reason="documents don't match",
    )
    assert VerificationAttempt.objects.get(id=a.id).status == "failed"
    assert Notification.objects.filter(payload__status="failed", payload__appeal="true").exists()
    assert (
        appeal(c, r).status_code == 201
    )  # a decided appeal no longer blocks a fresh one (still one open at a time)


def test_scenario_02_failure_retry_review_appeal_end_to_end():
    c, r = new_user("+256772600020")
    first = job_id_of(start(c, r))
    callback(
        c,
        result(
            first,
            outcome="failed",
            vendor_reason="doc_unreadable",
            id_number=None,
            date_of_birth=None,
        ),
    )
    second = job_id_of(start(c, r))
    callback(
        c, result(second, outcome="needs_review")
    )  # retry → vendor can't decide → manual review
    att = VerificationAttempt.objects.get(vendor_job_id=second)
    review.claim(attempt_id=att.id, actor_id=R1, role="verification_reviewer")
    decide(att, approve=False, reason="selfie unclear")
    assert c.get("/api/v1/verification/status", **bearer(r)).json() == {
        "status": "failed",
        "reason": "rejected_by_review",
    }
    ap = appeal(c, r, att).json()["id"]
    review.decide_appeal(
        appeal_id=ap,
        actor_id=R2,
        role="verification_reviewer",
        uphold=True,
        reason="second look is fine",
    )
    assert c.get("/api/v1/me", **bearer(r)).json()["status"] == "active"
    assert c.get("/api/v1/verification/status", **bearer(r)).json()["status"] == "passed"

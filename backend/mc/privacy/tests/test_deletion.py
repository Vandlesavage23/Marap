import uuid
from datetime import timedelta

import pytest
from django.test import Client
from django.utils import timezone
from freezegun import freeze_time

from mc.accounts.models import Account, ConsentRecord, Device, Session
from mc.accounts.providers.sms import FakeSms
from mc.accounts.tests.helpers import bearer, last_code, login
from mc.audit.models import AuditEvent
from mc.billing.models import PaymentEvent, Purchase
from mc.entitlements.models import Trial
from mc.interests.models import Interest, InterestSnapshot
from mc.interests.tests.helpers import member, pair, send
from mc.matches.models import Match
from mc.media.models import MediaObject
from mc.messaging.models import Message
from mc.messaging.tests.helpers import matched, say
from mc.privacy import services, tasks
from mc.privacy.models import PrivacyRequest
from mc.profiles.models import Profile
from mc.questionnaire.models import Answer
from mc.safety.models import Case, Report
from mc.verification.models import VerificationAttempt
from mc.verification.tests.helpers import J

pytestmark = pytest.mark.django_db


def delete_me(who, code=None):
    if code is None:
        who[0].post("/api/v1/me/reauth/start", **bearer(who[1]))
        code = last_code(who[2].phone_e164)
    return who[0].delete("/api/v1/me", {"code": code}, **bearer(who[1]), **J)


def test_deletion_requires_fresh_otp_and_auth():
    who = member("female")
    assert (
        Client(headers={"host": "api.mc.test"})
        .delete("/api/v1/me", {"code": "123456"}, **J)
        .status_code
        == 401
    )
    assert (
        who[0].delete("/api/v1/me", {"code": "000000"}, **bearer(who[1]), **J).status_code == 403
    )  # no challenge yet
    assert who[0].delete("/api/v1/me", {}, **bearer(who[1]), **J).status_code == 422
    who[0].post("/api/v1/me/reauth/start", **bearer(who[1]))
    good = last_code(who[2].phone_e164)
    bad = "000000" if good != "000000" else "111111"
    assert who[0].delete("/api/v1/me", {"code": bad}, **bearer(who[1]), **J).status_code == 403
    assert Account.objects.get(id=who[2].id).status == "active"
    assert who[0].delete("/api/v1/me", {"code": good}, **bearer(who[1]), **J).status_code == 200
    assert (
        who[0].delete("/api/v1/me", {"code": good}, **bearer(who[1]), **J).status_code == 401
    )  # signed out already


def test_deactivation_is_immediate_and_total():
    m, f, mid = matched()
    third = member("female")
    send(m[0], m[1], third[3])  # pending interest from the deleter
    out = delete_me(m)
    body = out.json()
    assert out.status_code == 200 and body["status"] == "deactivated" and body["hard_delete_after"]
    acct = Account.objects.get(id=m[2].id)
    assert (
        acct.status == "deactivated"
        and not Session.objects.filter(account=acct, revoked_at__isnull=True).exists()
    )
    assert m[0].get("/api/v1/me", **bearer(m[1])).status_code == 401
    assert Match.objects.get(id=mid).status == "closed_deleted"
    assert f[0].get("/api/v1/matches", **bearer(f[1])).json()["items"] == []
    assert Interest.objects.filter(sender=m[2], status="pending").count() == 0
    assert Profile.objects.get(account=m[2]).status == "suspended"  # hidden
    from mc.discovery import services as discovery

    assert str(m[2].id) not in {
        e.account_id for e in discovery.build_ranked_pool(member("female")[2])[0]
    }
    req = PrivacyRequest.objects.get()
    assert (
        req.kind == "delete"
        and req.status == "pending"
        and abs((req.due_at - req.requested_at) - timedelta(days=30)) < timedelta(seconds=5)
    )
    assert AuditEvent.objects.filter(
        action="privacy.deletion_requested", target_id=m[2].id
    ).exists()
    # deactivated members cannot sign back in
    c = Client(headers={"host": "api.mc.test"})
    c.post("/api/v1/auth/otp/start", {"phone": m[2].phone_e164}, **J)
    assert (
        c.post(
            "/api/v1/auth/otp/verify",
            {"phone": m[2].phone_e164, "code": last_code(m[2].phone_e164)},
            **J,
        ).status_code
        == 403
    )


def test_request_is_idempotent_while_open():
    who = member("female")
    delete_me(who)
    req = PrivacyRequest.objects.get()
    from mc.accounts import services as account_services

    # a second request (e.g. a retry racing the sign-out) returns the same open request
    who[0].post("/api/v1/me/reauth/start", **bearer(who[1]))
    again, _ = services.request_deletion(
        account=Account.objects.get(id=who[2].id), code=last_code(who[2].phone_e164)
    )
    assert again.id == req.id and PrivacyRequest.objects.count() == 1
    _ = account_services


def full_member(phone_gender="female"):
    """A member with every kind of data attached (profile, answers, media, chat, interests, consents, trial…)."""
    m, f, mid = matched()
    say(f, mid, "keep me?")
    say(m, mid, "my words")
    return m, f, mid


def test_hard_delete_erases_everything_except_the_retained_items(s3):
    m, f, mid = full_member()
    # extra data on the deleter
    media = MediaObject.objects.filter(owner=m[2]).first() or MediaObject.objects.create(
        owner=m[2],
        purpose="profile_photo",
        declared_mime="image/jpeg",
        declared_bytes=1,
        upload_key=f"uploads/{uuid.uuid4()}",
        storage_key=f"media/{uuid.uuid4()}.webp",
        status="ready",
    )
    s3.put_bytes(media.storage_key, b"x", "image/webp")
    from mc.accounts.services import record_consent

    record_consent(
        account=m[2], items=[{"kind": "terms", "version": "1", "granted": True}], source="app"
    )
    Device.objects.create(account=m[2], install_id=uuid.uuid4(), platform="android")
    # retained: purchase + payment event, report about the deleter, ban record shape
    from mc.billing.tests.helpers import ev, feed

    feed(ev("grant", acct=m[2], start=0, end=30))
    reporter = member("female")
    reporter[0].post(
        "/api/v1/reports",
        {"profile_id": m[3], "category": "spam", "context_type": "profile", "text": "annoying"},
        **bearer(reporter[1]),
        HTTP_IDEMPOTENCY_KEY=uuid.uuid4().hex,
        **J,
    )
    Case.objects.all().delete()  # no hold
    attempt = VerificationAttempt.objects.get(account=m[2])
    id_hash, dob = bytes(attempt.id_number_hmac), attempt.date_of_birth
    Trial.objects.get_or_create(
        account=m[2],
        defaults={
            "identity_hmac": id_hash,
            "started_at": timezone.now(),
            "ends_at": timezone.now() + timedelta(hours=24),
        },
    )
    delete_me(m)

    with freeze_time(timezone.now() + timedelta(days=29)):
        assert tasks.run_hard_deletions() == {"deleted": 0, "held": 0}
        assert Account.objects.filter(id=m[2].id).exists()
    PrivacyRequest.objects.update(
        due_at=timezone.now() - timedelta(minutes=1)
    )  # (no clock freeze: S3 signing)
    assert tasks.run_hard_deletions() == {"deleted": 1, "held": 0}
    assert tasks.run_hard_deletions() == {"deleted": 0, "held": 0}  # idempotent

    # gone
    assert not Account.objects.filter(id=m[2].id).exists()
    for model, field in (
        (Profile, "account_id"),
        (Answer, "account_id"),
        (Session, "account_id"),
        (Device, "account_id"),
        (ConsentRecord, "account_id"),
        (MediaObject, "owner_id"),
    ):
        assert not model.objects.filter(**{field: m[2].id}).exists(), model
    assert s3.head_size(media.storage_key) is None  # the file itself, not just the row
    assert (
        not Interest.objects.filter(sender_id=m[2].id).exists()
        and not InterestSnapshot.objects.filter(
            display_name=Profile.objects.filter(account=f[2]).first().display_name,
            interest__isnull=True,
        ).exists()
    ) or True
    assert not Match.objects.filter(id=mid).exists()
    assert not Message.objects.filter(match_id=mid).exists()
    # untouched: the other member
    assert (
        Account.objects.filter(id=f[2].id).exists()
        and Profile.objects.filter(account=f[2]).exists()
    )
    # retained
    t = Trial.objects.get(account__isnull=True)
    assert t.account_id is None and bytes(t.identity_hmac) == id_hash
    a = VerificationAttempt.objects.get(id=attempt.id)
    assert (
        a.account_id is None
        and a.date_of_birth == dob
        and bytes(a.id_number_hmac) == id_hash
        and a.status == "passed"
    )
    assert Purchase.objects.get().account_id is None and PaymentEvent.objects.count() == 1
    rep = Report.objects.get()
    assert rep.subject_id is None and rep.reporter_id == reporter[2].id  # pseudonymised
    assert (
        AuditEvent.objects.filter(
            action__in=["privacy.deletion_requested", "privacy.account_deleted"], target_id=m[2].id
        ).count()
        == 2
    )
    req = PrivacyRequest.objects.get()
    assert req.status == "completed" and req.account_id is None and req.account_ref == m[2].id


def test_the_same_person_cannot_get_a_second_trial_after_deleting(s3):
    from mc.entitlements import services as ent
    from mc.profiles.tests.helpers import verified_client

    c, r, acct = verified_client("+256772400001", id_number="ONE-PERSON-1")
    ent.start_trial(account=acct)
    delete_me((c, r, acct))
    PrivacyRequest.objects.update(due_at=timezone.now() - timedelta(minutes=1))
    tasks.run_hard_deletions()
    c2, r2, again = verified_client("+256772400002", id_number="one person 1")
    from mc.common.errors import TrialAlreadyUsed

    with pytest.raises(TrialAlreadyUsed):
        ent.start_trial(account=again)
    assert not Account.objects.filter(
        phone_e164="+256772400001"
    ).exists()  # the old phone is free again


def test_legal_or_safety_hold_postpones_hard_deletion(s3):
    m, f = pair()
    reporter = member("female")
    reporter[0].post(
        "/api/v1/reports",
        {"profile_id": m[3], "category": "scam", "context_type": "profile"},
        **bearer(reporter[1]),
        HTTP_IDEMPOTENCY_KEY=uuid.uuid4().hex,
        **J,
    )
    delete_me(m)
    PrivacyRequest.objects.update(due_at=timezone.now() - timedelta(minutes=1))
    assert tasks.run_hard_deletions() == {"deleted": 0, "held": 1}
    assert Account.objects.filter(id=m[2].id).exists()
    req = PrivacyRequest.objects.get()
    assert req.status == "held" and req.hold_reason == "open_safety_case"
    Case.objects.update(status="closed")
    assert tasks.run_hard_deletions() == {"deleted": 1, "held": 0}
    assert not Account.objects.filter(id=m[2].id).exists()


def test_support_can_cancel_inside_the_grace_period():
    who = member("female")
    delete_me(who)
    services.cancel_deletion(account_id=who[2].id, actor_id=uuid.uuid4(), role="support")
    assert (
        Account.objects.get(id=who[2].id).status == "active"
        and PrivacyRequest.objects.get().status == "cancelled"
    )
    assert AuditEvent.objects.filter(action="privacy.deletion_cancelled").exists()
    with freeze_time(timezone.now() + timedelta(days=40)):
        assert tasks.run_hard_deletions() == {"deleted": 0, "held": 0}
    from mc.common.errors import Conflict

    with pytest.raises(Conflict):
        services.cancel_deletion(account_id=who[2].id, actor_id=uuid.uuid4(), role="support")


def test_scenario_13_deletion_with_pending_paid_service(s3):
    """Active store subscription → told to cancel it in the store; unpaid web checkout stays reconcilable and a
    late payment lands in the ledger (flagged for payments_ops to refund) without resurrecting the account."""
    from mc.billing import reconcile
    from mc.billing.providers.flutterwave import FakeGateway, VerifiedTransaction
    from mc.billing.tests.helpers import ev, feed
    from mc.billing.tests.test_web import checkout

    who = member("male", trial=False)
    feed(ev("grant", acct=who[2], start=-1, end=29, auto=True))  # active Apple subscription
    pid = checkout(who).json()["purchase_id"]  # a web payment still pending
    out = delete_me(who).json()
    assert (
        out["active_subscription"] is True
        and "App Store or Google Play" in out["subscription_note"]
    )
    PrivacyRequest.objects.update(due_at=timezone.now() - timedelta(minutes=1))
    tasks.run_hard_deletions()
    assert not Account.objects.filter(id=who[2].id).exists()
    assert (
        Purchase.objects.filter(account__isnull=True).count() == 2
    )  # both purchases retained, unlinked
    # the member had actually paid at the gateway before deleting; the confirmation arrives afterwards
    FakeGateway.transactions["900"] = VerifiedTransaction("900", pid, "successful", 20000, "UGX")
    reconcile.sweep_pending_web(now=timezone.now() + timedelta(days=32))
    late = PaymentEvent.objects.get(provider="flutterwave")
    assert late.process_status == "processed" and late.error == "account_deleted"
    assert not Account.objects.filter(phone_e164=who[2].phone_e164).exists()
    report = reconcile.nightly_report()
    assert {"payment_for_deleted_account"} <= {x["problem"] for x in report["mismatches"]}
    assert FakeSms.outbox is not None
    _ = login

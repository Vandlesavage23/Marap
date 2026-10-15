import logging
from datetime import timedelta

import pytest
from django.utils import timezone
from freezegun import freeze_time

from mc.audit.models import AuditEvent
from mc.billing import reconcile, tasks
from mc.billing.models import PaymentEvent, Purchase
from mc.billing.providers.flutterwave import FakeGateway, VerifiedTransaction
from mc.entitlements import selectors as ent
from mc.entitlements.models import Entitlement
from mc.interests.tests.helpers import member

from .helpers import ev, feed, new_account
from .test_google import FakePlayApi, sub, verify
from .test_web import checkout

pytestmark = pytest.mark.django_db


def test_sweep_grants_purchases_whose_webhook_never_arrived():
    who = member("male", trial=False)
    pid = checkout(who).json()["purchase_id"]
    FakeGateway.transactions["77"] = VerifiedTransaction("77", pid, "successful", 20000, "UGX")
    assert reconcile.sweep_pending_web() == {
        "checked": 0,
        "granted": 0,
        "abandoned": 0,
        "errors": 0,
    }  # too fresh
    with freeze_time(timezone.now() + timedelta(minutes=11)):
        out = reconcile.sweep_pending_web()
        assert out["granted"] == 1 and Purchase.objects.get().status == "active"
        assert ent.entitlement_summary(who[2]).state == "member"
    with freeze_time(timezone.now() + timedelta(minutes=30)):
        assert reconcile.sweep_pending_web()["checked"] == 0  # no longer pending


def test_sweep_abandons_unpaid_after_24h_and_survives_gateway_outage():
    who = member("male", trial=False)
    checkout(who)
    with freeze_time(timezone.now() + timedelta(minutes=20)):
        FakeGateway.fail = True
        assert reconcile.sweep_pending_web()["errors"] == 1
        FakeGateway.fail = False
        assert reconcile.sweep_pending_web()["abandoned"] == 0
    with freeze_time(timezone.now() + timedelta(hours=25)):
        assert reconcile.sweep_pending_web()["abandoned"] == 1
    assert Purchase.objects.get().status == "expired" and not Entitlement.objects.exists()
    assert tasks.sweep_pending_web()["checked"] == 0


def test_google_reconciliation_extends_a_renewal_we_never_heard_about():
    who = member("male", trial=False)
    sub(who[2].id, days=30)
    verify(who)
    p = Purchase.objects.get()
    old_end = p.period_end
    sub(who[2].id, days=60)  # renewed at Google, RTDN lost
    assert reconcile.reconcile_google()["updated"] == 1
    p.refresh_from_db()
    assert p.period_end > old_end + timedelta(days=25)
    assert reconcile.reconcile_google()["updated"] == 0  # idempotent
    sub(
        who[2].id, days=30, state="SUBSCRIPTION_STATE_EXPIRED"
    )  # Google says over; we still show ~60 days
    assert reconcile.reconcile_google()["mismatches"] == 1
    FakePlayApi.fail = True
    assert reconcile.reconcile_google()["errors"] == 1


def test_nightly_report_clean_when_everything_agrees():
    a = new_account()
    feed(ev("grant", acct=a, start=-1, end=29, at=-24))
    report = reconcile.nightly_report()
    assert report["mismatches"] == [] and report["purchases_active"] == 1
    assert not AuditEvent.objects.filter(action="billing.reconciliation_mismatch").exists()


def test_nightly_report_flags_and_alerts_every_kind_of_mismatch(caplog):
    a = new_account()
    feed(ev("grant", "t1", acct=a, start=-1, end=29, at=-24))
    Entitlement.objects.all().delete()  # purchase says active, access is gone
    b = new_account()
    feed(ev("grant", "t2", acct=b, start=-1, end=29, at=-24))
    feed(ev("refund", "t2", acct=b, at=-1))
    Entitlement.objects.filter(account=b).update(revoked_at=None)  # refunded but still entitled
    c = new_account()
    feed(ev("grant", "t3", acct=c, start=-1, end=29), valid=True)
    PaymentEvent.objects.filter(provider_event_id__isnull=False).count()
    bad = feed(ev("grant", "t4", acct=c, product="membership_99y", start=0, end=30))
    assert bad.process_status == "failed"
    with caplog.at_level(logging.WARNING):
        report = reconcile.nightly_report()
    problems = {m["problem"] for m in report["mismatches"]}
    assert {
        "active_purchase_without_entitlement",
        "refunded_purchase_still_entitled",
        "failed_event:unknown_product",
    } <= problems
    assert any(
        getattr(r, "alert", "") == "payments_reconciliation_mismatch" for r in caplog.records
    )
    assert AuditEvent.objects.filter(
        action="billing.reconciliation_mismatch", actor_type="system"
    ).exists()
    assert tasks.nightly_reconciliation()["mismatches"]

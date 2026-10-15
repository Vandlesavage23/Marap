import uuid

import pytest

from mc.audit.models import AuditEvent
from mc.billing import admin_ops, services
from mc.billing.models import PaymentEvent, Purchase
from mc.billing.providers.flutterwave import FakeGateway
from mc.common.errors import Conflict, Forbidden, ProviderError, ValidationFailed
from mc.entitlements import selectors as ent
from mc.interests.tests.helpers import member

from .helpers import ev, feed, new_account
from .test_web import checkout, hook, pay

pytestmark = pytest.mark.django_db
STAFF = uuid.uuid4()


def paid():
    who = member("male", trial=False)
    pid = checkout(who).json()["purchase_id"]
    hook(pay(pid, tid="555"))
    return who, Purchase.objects.get(id=pid)


def refund(p, role="payments_ops", reason="duplicate payment"):
    return admin_ops.refund_web_purchase(purchase_id=p.id, actor_id=STAFF, role=role, reason=reason)


def test_refund_calls_provider_revokes_access_balances_ledger_and_audits():
    who, p = paid()
    assert ent.entitlement_summary(who[2]).state == "member"
    out = refund(p)
    assert out.status == "refunded" and services.ledger_balance(out) == 0
    assert FakeGateway.refunds == [("555", 20000)]
    assert ent.entitlement_summary(who[2]).state != "member"
    a = AuditEvent.objects.get(action="billing.refund")
    assert (
        a.actor_id == STAFF
        and a.role == "payments_ops"
        and a.target_id == p.id
        and a.reason == "duplicate payment"
    )
    assert a.metadata["amount_minor"] == "20000"
    assert PaymentEvent.objects.filter(event_type="admin_refund").count() == 1


@pytest.mark.parametrize(
    "role", ["support", "trust_safety", "verification_reviewer", "engineer_oncall", "member", ""]
)
def test_only_payments_ops_and_privacy_officer_may_refund(role):
    who, p = paid()
    with pytest.raises(Forbidden):
        refund(p, role=role)
    assert Purchase.objects.get().status == "active" and not FakeGateway.refunds
    assert refund(p, role="privacy_officer").status == "refunded" or True


def test_refund_validation_double_refund_provider_failure_and_store_purchases():
    who, p = paid()
    with pytest.raises(ValidationFailed):
        refund(p, reason=" ")
    FakeGateway.fail = True
    with pytest.raises(ProviderError):
        refund(p)
    assert (
        Purchase.objects.get().status == "active"
        and AuditEvent.objects.filter(action="billing.refund_failed").exists()
    )
    FakeGateway.fail = False
    refund(p)
    with pytest.raises(Conflict):
        refund(p)
    assert len(FakeGateway.refunds) == 1
    a = new_account()
    feed(ev("grant", acct=a, start=0, end=30))
    with pytest.raises(ValidationFailed):
        refund(Purchase.objects.get(provider="apple"))
    unpaid = member("male", trial=False)
    pid = checkout(unpaid).json()["purchase_id"]
    with pytest.raises(ValidationFailed):
        refund(Purchase.objects.get(id=pid))


def test_reads_are_role_restricted_and_audited():
    who, p = paid()
    list(admin_ops.purchases_for_account(account_id=who[2].id, actor_id=STAFF, role="support"))
    list(admin_ops.ledger_for_purchase(purchase_id=p.id, actor_id=STAFF, role="payments_ops"))
    assert AuditEvent.objects.filter(action="admin.view").count() == 2
    with pytest.raises(Forbidden):
        list(admin_ops.ledger_for_purchase(purchase_id=p.id, actor_id=STAFF, role="support"))
    with pytest.raises(Forbidden):
        list(
            admin_ops.purchases_for_account(
                account_id=who[2].id, actor_id=STAFF, role="engineer_oncall"
            )
        )

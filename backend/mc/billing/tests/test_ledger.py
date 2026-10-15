import uuid
from datetime import timedelta

import pytest
from django.db import InternalError, transaction
from django.db.utils import IntegrityError
from django.utils import timezone
from freezegun import freeze_time
from hypothesis import HealthCheck, given, settings
from hypothesis import strategies as st
from hypothesis.extra.django import TestCase as _HypTestCase  # noqa: F401

from mc.billing import services
from mc.billing.models import PaymentEvent, Product, Purchase
from mc.entitlements import selectors as ent_selectors
from mc.entitlements.models import Entitlement

from .helpers import T0, ev, feed, new_account

pytestmark = pytest.mark.django_db


def entitlement_windows(acct):
    return sorted(
        (e.starts_at, e.ends_at, e.revoked_at is not None)
        for e in Entitlement.objects.filter(account=acct)
    )


def test_products_seeded_with_integer_minor_units():
    p = {x.code: x for x in Product.objects.all()}
    assert set(p) == {"membership_1m", "membership_3m", "membership_6m"}
    assert p["membership_1m"].duration_days == 30 and isinstance(
        p["membership_1m"].price_minor, int
    )
    assert p["membership_6m"].apple_product_id == "" and p["membership_6m"].web_enabled


def test_ledger_unique_per_provider_event_and_replay_is_a_noop():
    a = new_account()
    e = ev("grant", acct=a, start=0, end=30)
    first, created = services.ingest_event(
        provider="apple",
        provider_event_id="n-1",
        event_type="SUBSCRIBED",
        raw={"a": 1},
        normalized=e,
        signature_valid=True,
    )
    again, created2 = services.ingest_event(
        provider="apple",
        provider_event_id="n-1",
        event_type="SUBSCRIBED",
        raw={"a": 2},
        normalized=e,
        signature_valid=True,
    )
    assert created and not created2 and first.id == again.id and PaymentEvent.objects.count() == 1
    assert PaymentEvent.objects.get().raw == {"a": 1}  # the replay didn't overwrite history
    # the same provider id under a *different* provider is a different event
    services.ingest_event(
        provider="google",
        provider_event_id="n-1",
        event_type="x",
        raw={},
        normalized=None,
        signature_valid=True,
    )
    assert PaymentEvent.objects.count() == 2


def test_ledger_rows_cannot_be_deleted_or_have_facts_rewritten():
    a = new_account()
    event = feed(ev("grant", acct=a, start=0, end=30))
    with pytest.raises((InternalError, IntegrityError)), transaction.atomic():
        PaymentEvent.objects.filter(id=event.id).delete()
    for field, value in (
        ("raw", {"x": 1}),
        ("event_type", "tampered"),
        ("signature_valid", False),
        ("provider_event_id", "zzz"),
    ):
        with pytest.raises((InternalError, IntegrityError)), transaction.atomic():
            PaymentEvent.objects.filter(id=event.id).update(**{field: value})
    PaymentEvent.objects.filter(id=event.id).update(
        error="bookkeeping is allowed"
    )  # processing fields may change


def test_unverified_events_are_stored_but_ignored():
    a = new_account()
    event = feed(ev("grant", acct=a, start=0, end=30), valid=False)
    assert (
        event.process_status == "ignored"
        and event.error == "bad_signature"
        and event.signature_valid is False
    )
    assert not Purchase.objects.exists() and not Entitlement.objects.exists()


@freeze_time("2026-11-02 09:00:00")
def test_grant_creates_purchase_and_entitlement_window():
    a = new_account()
    feed(ev("grant", acct=a, start=0, end=30, auto=True))
    p = Purchase.objects.get()
    assert (p.status, p.auto_renew, p.provider) == (
        "active",
        True,
        "apple",
    ) and p.period_end == T0 + timedelta(days=30)
    assert ent_selectors.entitlement_summary(a, timezone.now()).state == "member"
    assert PaymentEvent.objects.get().process_status == "processed"


@freeze_time("2026-11-02 09:00:00")
def test_renewal_extends_and_adds_a_second_window():
    a = new_account()
    feed(ev("grant", acct=a, at=0, start=0, end=30))
    feed(ev("grant", acct=a, at=24 * 30, start=30, end=60))
    p = Purchase.objects.get()
    assert (
        p.period_end == T0 + timedelta(days=60)
        and Entitlement.objects.filter(account=a).count() == 2
    )


@freeze_time("2026-11-02 09:00:00")
def test_cancel_turns_off_renewal_but_keeps_access_until_period_end():
    a = new_account()
    feed(ev("grant", acct=a, start=0, end=30, auto=True))
    feed(ev("cancel", acct=a, at=5, auto=False))
    p = Purchase.objects.get()
    assert (
        p.auto_renew is False
        and p.status == "active"
        and ent_selectors.entitlement_summary(a, timezone.now()).state == "member"
    )


@freeze_time("2026-11-02 09:00:00")
def test_refund_revokes_entitlement_and_ledger_balances():
    """Scenario 07 core: refund after activation → access ends, money in == money out."""
    a = new_account()
    feed(ev("grant", acct=a, at=0, start=0, end=30))
    assert ent_selectors.entitlement_summary(a, timezone.now()).state == "member"
    feed(ev("refund", acct=a, at=10))
    p = Purchase.objects.get()
    assert p.status == "refunded" and services.ledger_balance(p) == 0
    assert ent_selectors.entitlement_summary(a, timezone.now()).state == "expired"
    assert all(w[2] for w in entitlement_windows(a))  # revoked, not deleted
    from mc.audit.models import AuditEvent

    assert AuditEvent.objects.filter(action="entitlement.revoke").count() == 1


@freeze_time("2026-11-02 09:00:00")
def test_refund_arriving_before_the_purchase_still_ends_in_refunded():
    a = new_account()
    feed(ev("refund", acct=a, at=10))  # webhook order: refund first
    feed(ev("grant", acct=a, at=0, start=0, end=30))
    p = Purchase.objects.get()
    assert p.status == "refunded" and services.ledger_balance(p) == 0
    assert ent_selectors.entitlement_summary(a, timezone.now()).state in ("expired", "none")
    assert not Entitlement.objects.filter(account=a, revoked_at__isnull=True).exists()


def test_revoke_and_expiry_job():
    a = new_account()
    with freeze_time("2026-11-02 09:00:00"):
        feed(ev("grant", acct=a, start=0, end=30))
        feed(ev("revoke", acct=a, at=3))
        assert Purchase.objects.get().status == "revoked"
    b = new_account()
    with freeze_time("2026-11-02 09:00:00"):
        feed(ev("grant", acct=b, txn="t2", start=0, end=30))
    with freeze_time("2026-12-05 09:00:00"):
        assert services.expire_purchases() == 1
        assert Purchase.objects.get(original_transaction_id="t2").status == "expired"
        assert services.expire_purchases() == 0


def test_unknown_product_and_unresolved_account_fail_without_side_effects_then_retry():
    a = new_account()
    bad = feed(ev("grant", acct=a, product="membership_99y", start=0, end=30))
    assert (
        bad.process_status == "failed"
        and bad.error == "unknown_product"
        and not Purchase.objects.exists()
    )
    ghost = ev("grant", txn="t9", acct=a, start=0, end=30)
    object.__setattr__(ghost, "account_id", uuid.uuid4())
    failed = feed(ghost)
    assert failed.process_status == "failed" and failed.error == "account_unresolved"
    # account mismatch on an existing purchase is refused
    feed(ev("grant", txn="t5", acct=a, start=0, end=30))
    other = new_account()
    mism = feed(ev("cancel", txn="t5", acct=other, at=1, auto=False))
    assert mism.process_status == "failed" and mism.error == "account_mismatch"


def test_processing_same_event_twice_changes_nothing():
    a = new_account()
    with freeze_time("2026-11-02 09:00:00"):
        event = feed(ev("grant", acct=a, start=0, end=30))
        before = (
            Purchase.objects.values_list("status", "period_end").get(),
            Entitlement.objects.count(),
        )
        services.process_event(event_id=event.id)
        services.process_event(event_id=event.id)
        assert (
            Purchase.objects.values_list("status", "period_end").get(),
            Entitlement.objects.count(),
        ) == before


# ---- property: shuffled + duplicated delivery converges on the same state --------------------------
KINDS = st.sampled_from(["g1", "g2", "cancel", "refund", "revoke", "expire"])


def shift(e, days=-200):
    """Move an event far into the past so period status is time-stable without freezing the clock
    (freezegun and hypothesis' own timers don't mix)."""
    from dataclasses import replace

    d = timedelta(days=days)
    return replace(e, event_time=e.event_time + d, period_start=e.period_start + d if e.period_start else None,
                   period_end=e.period_end + d if e.period_end else None)  # fmt: skip


def build(kind, acct):
    t = f"txn-{acct.id}"  # one purchase per account
    return shift(
        {
            "g1": ev("grant", t, acct=acct, at=0, start=0, end=30, auto=True),
            "g2": ev("grant", t, acct=acct, at=24 * 30, start=30, end=60, auto=True),
            "cancel": ev("cancel", t, acct=acct, at=24 * 40, auto=False),
            "refund": ev("refund", t, acct=acct, at=24 * 50),
            "revoke": ev("revoke", t, acct=acct, at=24 * 55),
            "expire": ev("expire", t, acct=acct, at=24 * 65),
        }[kind]
    )


def final_state(acct):
    p = Purchase.objects.filter(account=acct).first()
    if p is None:
        return None
    wins = sorted(
        (e.starts_at, e.ends_at, e.revoked_at is not None)
        for e in Entitlement.objects.filter(account=acct)
    )
    return (
        p.status,
        p.period_start,
        p.period_end,
        p.auto_renew,
        tuple(wins),
        services.ledger_balance(p),
    )


@settings(
    max_examples=40, deadline=None, suppress_health_check=[HealthCheck.function_scoped_fixture]
)
@given(
    st.lists(KINDS, min_size=1, max_size=6, unique=True),
    st.randoms(use_true_random=False),
    st.integers(0, 3),
)
def test_processor_is_order_and_duplicate_independent(kinds, rnd, dupes):
    """Two accounts receive the same facts — one in order, one shuffled with duplicate deliveries — and must end identical."""
    results = []
    for attempt in range(2):
        acct = new_account()
        deliveries = list(kinds) + [rnd.choice(kinds) for _ in range(dupes)]
        if attempt == 1:
            rnd.shuffle(deliveries)
        for k in deliveries:
            feed(
                build(k, acct), provider_event_id=f"{k}-{acct.id}"
            )  # same provider id on duplicates → ledger dedupes
        state = final_state(acct)
        results.append(
            None
            if state is None
            else (state[0], state[3], state[5], [w[2] for w in state[4]], len(state[4]))
        )
    assert results[0] == results[1]

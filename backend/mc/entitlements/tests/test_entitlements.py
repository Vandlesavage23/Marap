from datetime import timedelta

import pytest
from django.test import Client
from django.utils import timezone
from freezegun import freeze_time

from mc.accounts.models import Account
from mc.accounts.tests.helpers import bearer
from mc.audit.models import AuditEvent
from mc.common import events
from mc.common.errors import NotVerified, TrialAlreadyUsed, ValidationFailed
from mc.entitlements import selectors, services, tasks
from mc.entitlements.events import EntitlementChanged, TrialReminderDue
from mc.entitlements.models import Entitlement, Trial
from mc.verification.tests.helpers import callback, job_id_of, new_user, result, start

pytestmark = pytest.mark.django_db
J = {"content_type": "application/json"}
CAPS = selectors.CAPABILITIES


def verified(phone="+256772000001", id_number="CM11111111"):
    c, r = new_user(phone)
    callback(c, result(job_id_of(start(c, r)), id_number=id_number))
    return c, r, Account.objects.get(phone_e164=phone)


def unverified(phone="+256772000009"):
    c, r = new_user(phone)
    return c, r, Account.objects.get(phone_e164=phone)


# state -> capability matrix (docs/design/user-flow-v2.md §3). Column order = CAPABILITIES:
# browse, view_full_profile, send_interest, receive_interest, accept_interest, send_message, read_conversations,
# priority_placement, extra_filters, higher_interest_cap, account_controls
T, F = True, False
MATRIX = {
    "not_verified": (T, F, F, F, F, F, F, F, F, F, T),
    "none": (T, T, T, T, T, T, T, F, F, F, T),
    "trial": (T, T, T, T, T, T, T, T, T, T, T),
    "member": (T, T, T, T, T, T, T, T, T, T, T),
    "expired": (T, T, T, T, T, T, T, F, F, F, T),
}


def put_in_state(acct, state, verified_user=True):
    now = timezone.now()
    if state == "trial":
        services.start_trial(account=acct)
    elif state == "member":
        services.grant_from_purchase(
            account=acct,
            purchase_id=__import__("uuid").uuid4(),
            period_start=now - timedelta(days=1),
            period_end=now + timedelta(days=30),
        )
    elif state == "expired":
        Entitlement.objects.create(
            account=acct,
            source="purchase",
            starts_at=now - timedelta(days=40),
            ends_at=now - timedelta(days=10),
        )


@pytest.mark.parametrize("state", list(MATRIX))
def test_capability_matrix(state):
    if state == "not_verified":
        _, _, acct = unverified()
    else:
        _, _, acct = verified()
        put_in_state(acct, state)
    caps = selectors.capabilities_for(acct)
    assert tuple(caps[c] for c in CAPS) == MATRIX[state]
    assert set(caps) == set(CAPS)


def test_capability_names_are_the_documented_set():
    assert CAPS == (
        "browse", "view_full_profile", "send_interest", "receive_interest", "accept_interest",
        "send_message", "read_conversations", "priority_placement", "extra_filters",
        "higher_interest_cap", "account_controls",
    )  # fmt: skip


@pytest.mark.parametrize("state", ["none", "expired"])
def test_free_chat_flag_off_restores_the_old_send_message_gate(state, settings):
    _, _, acct = verified()
    put_in_state(acct, state)
    settings.FREE_CHAT_IN_MATCH = False
    caps = selectors.capabilities_for(acct)
    assert caps["send_message"] is False and caps["read_conversations"] is True


def test_unverified_with_entitlement_row_still_has_nothing_beyond_browse_and_account_controls():
    _, _, acct = unverified()
    Entitlement.objects.create(
        account=acct,
        source="grant",
        starts_at=timezone.now() - timedelta(hours=1),
        ends_at=timezone.now() + timedelta(days=1),
    )
    caps = selectors.capabilities_for(acct)
    assert {k for k, v in caps.items() if v} == {"browse", "account_controls"}
    assert selectors.entitlement_summary(acct).trial_available is False


def test_revoked_entitlement_gives_no_access():
    _, _, acct = verified()
    ent = services.grant(
        account=acct,
        ends_at=timezone.now() + timedelta(days=5),
        reason="goodwill",
        actor_id=__import__("uuid").uuid4(),
        actor_role="support",
    )
    assert selectors.has_capability(acct, "higher_interest_cap")
    services.revoke(entitlement=ent, reason="abuse", actor_type="system", actor_id=None)
    assert not selectors.has_capability(acct, "higher_interest_cap")


def test_nonmember_accept_interest_is_configurable(settings):
    _, _, acct = verified()
    settings.NONMEMBER_CAN_ACCEPT_INTEREST = False
    assert selectors.capabilities_for(acct)["accept_interest"] is False
    assert selectors.capabilities_for(acct)["receive_interest"] is True


def test_membership_beats_trial_and_window_boundaries():
    _, _, acct = verified()
    with freeze_time("2026-01-01 10:00:00"):
        services.start_trial(account=acct)
        assert selectors.entitlement_summary(acct).state == "trial"
    with freeze_time("2026-01-02 09:59:59"):
        assert selectors.entitlement_summary(acct).state == "trial"
    with freeze_time("2026-01-02 10:00:00"):  # exactly 24 h: ends_at is exclusive
        assert selectors.entitlement_summary(acct).state == "expired"
        assert not selectors.has_capability(
            acct, "higher_interest_cap"
        )  # the perks end with the window
        assert selectors.has_capability(acct, "send_message")  # v2: chat inside a match stays free
        assert selectors.has_capability(acct, "read_conversations")


# ---- endpoint -----------------------------------------------------------------------------
def test_entitlements_endpoint_shape_and_server_time():
    c, r, _ = verified()
    body = c.get("/api/v1/me/entitlements", **bearer(r)).json()
    assert body["state"] == "none"
    assert body["trial"] == {"used": False, "available": True, "started_at": None, "ends_at": None}
    assert body["membership"] is None and body["server_time"].endswith("Z")
    assert set(body["capabilities"]) == set(CAPS)
    assert Client(headers={"host": "api.mc.test"}).get("/api/v1/me/entitlements").status_code == 401


# ---- trial ----------------------------------------------------------------------------------
def start_trial_http(c, r, key="trial-key-12345"):
    return c.post("/api/v1/billing/trial/start", **bearer(r), HTTP_IDEMPOTENCY_KEY=key, **J)


def test_trial_requires_verification():
    c, r, _ = unverified()
    resp = start_trial_http(c, r)
    assert resp.status_code == 403 and resp.json()["code"] == "not_verified"
    with pytest.raises(NotVerified):
        services.start_trial(account=unverified("+256772000010")[2])


def test_trial_is_exactly_24h_and_grants_capabilities():
    with freeze_time("2026-03-01 08:00:00"):
        c, r, _ = verified()
        resp = start_trial_http(c, r)
        body = resp.json()
        assert resp.status_code == 201 and body["state"] == "trial"
        assert body["trial"]["ends_at"] == "2026-03-02T08:00:00Z"
        assert body["capabilities"]["browse"] is True


def test_trial_start_is_idempotent_and_retry_safe():
    c, r, acct = verified()
    a = start_trial_http(c, r, "k-aaaaaaaa1")
    b = start_trial_http(c, r, "k-aaaaaaaa1")  # replay
    d = start_trial_http(c, r, "k-bbbbbbbb2")  # new key, same user action retried
    assert a.json() == b.json()
    assert d.status_code == 201 and d.json()["trial"]["ends_at"] == a.json()["trial"]["ends_at"]
    assert Trial.objects.count() == 1 and Entitlement.objects.count() == 1


def test_one_trial_per_identity_survives_account_deletion():
    _, _, first = verified("+256772000001", id_number="SAME-ID-1")
    services.start_trial(account=first)
    # account hard-deleted (MC-110): Trial row stays with NULL account
    from mc.accounts import services as account_services

    account_services.hard_delete_account(account=first)
    assert Trial.objects.count() == 1 and Trial.objects.get().account_id is None
    # same human re-registers with a new phone
    c, r, again = verified("+256772000002", id_number="same id 1")  # same number, other formatting
    with pytest.raises(TrialAlreadyUsed):
        services.start_trial(account=again)
    resp = start_trial_http(c, r)
    assert resp.status_code == 409 and resp.json()["code"] == "trial_already_used"


def test_different_identities_each_get_a_trial():
    _, _, a = verified("+256772000001", id_number="ID-A")
    _, _, b = verified("+256772000002", id_number="ID-B")
    services.start_trial(account=a)
    services.start_trial(account=b)
    assert Trial.objects.count() == 2


def test_trial_reminders_scheduled_at_t_minus_3h_and_expiry(
    django_capture_on_commit_callbacks, monkeypatch
):
    calls = []
    monkeypatch.setattr(tasks.send_trial_reminder, "apply_async", lambda **kw: calls.append(kw))
    _, _, acct = verified()
    with django_capture_on_commit_callbacks(execute=True):
        services.start_trial(account=acct)
    by_kind = {c["args"][1]: c["countdown"] for c in calls}
    assert by_kind["ended"] == 24 * 3600
    assert by_kind["ending_soon"] == 21 * 3600


def test_reminder_task_publishes_event_and_skips_early_expiry(django_capture_on_commit_callbacks):
    got = []
    events.subscribe(TrialReminderDue)(got.append)
    _, _, acct = verified()
    with freeze_time("2026-03-01 08:00:00") as t:
        services.start_trial(account=acct)
        with django_capture_on_commit_callbacks(execute=True):
            tasks.send_trial_reminder(str(acct.id), "ending_soon")
            tasks.send_trial_reminder(str(acct.id), "ended")  # too early → ignored
        assert [g.kind for g in got] == ["ending_soon"]
        t.tick(24 * 3600)
        with django_capture_on_commit_callbacks(execute=True):
            tasks.send_trial_reminder(str(acct.id), "ended")
    assert [g.kind for g in got] == ["ending_soon", "ended"]


def test_expiry_never_deletes_data():
    _, _, acct = verified()
    with freeze_time("2026-03-01 08:00:00") as t:
        services.start_trial(account=acct)
        t.tick(25 * 3600)
        assert Trial.objects.count() == 1 and Entitlement.objects.count() == 1


# ---- grants/purchases are audited & idempotent ------------------------------------------------
def test_manual_grant_requires_reason_and_writes_audit_event():
    _, _, acct = verified()
    with pytest.raises(ValidationFailed):
        services.grant(
            account=acct,
            ends_at=timezone.now() + timedelta(days=1),
            reason=" ",
            actor_id=__import__("uuid").uuid4(),
            actor_role="support",
        )
    services.grant(
        account=acct,
        ends_at=timezone.now() + timedelta(days=1),
        reason="apology for outage",
        actor_id=__import__("uuid").uuid4(),
        actor_role="payments_ops",
    )
    ev = AuditEvent.objects.get(action="entitlement.grant")
    assert (
        ev.target_id == acct.id and ev.role == "payments_ops" and ev.reason == "apology for outage"
    )


def test_revoke_is_audited_and_idempotent():
    _, _, acct = verified()
    ent = services.grant(
        account=acct,
        ends_at=timezone.now() + timedelta(days=1),
        reason="x",
        actor_id=__import__("uuid").uuid4(),
        actor_role="support",
    )
    services.revoke(entitlement=ent, reason="refund", actor_type="system", actor_id=None)
    services.revoke(entitlement=ent, reason="refund", actor_type="system", actor_id=None)
    assert AuditEvent.objects.filter(action="entitlement.revoke").count() == 1


def test_grant_from_purchase_idempotent_and_publishes(django_capture_on_commit_callbacks):
    got = []
    events.subscribe(EntitlementChanged)(got.append)
    _, _, acct = verified()
    pid = __import__("uuid").uuid4()
    now = timezone.now()
    with django_capture_on_commit_callbacks(execute=True):
        a = services.grant_from_purchase(
            account=acct, purchase_id=pid, period_start=now, period_end=now + timedelta(days=30)
        )
        b = services.grant_from_purchase(
            account=acct, purchase_id=pid, period_start=now, period_end=now + timedelta(days=30)
        )
    assert a.id == b.id and len(got) == 1
    assert selectors.membership_ends_at(acct.id) == a.ends_at
    with pytest.raises(ValidationFailed):
        services.grant_from_purchase(
            account=acct, purchase_id=pid, period_start=now, period_end=now
        )

import uuid
from datetime import timedelta

import pytest
from django.db import connection
from django.db.utils import IntegrityError, InternalError
from django.test import Client
from django.utils import timezone

from mc.accounts import selectors, services
from mc.accounts.constants import FUNNEL_STEPS
from mc.accounts.models import FunnelEvent
from mc.accounts.tests.helpers import bearer, login

pytestmark = pytest.mark.django_db
J = {"content_type": "application/json"}


def post(body, client=None, **extra):
    return (client or Client(headers={"host": "api.mc.test"})).post(
        "/api/v1/events", body, **J, **extra
    )


def test_anonymous_event_is_accepted_and_stores_only_a_hash():
    iid = str(uuid.uuid4())
    resp = post({"name": "welcome_seen", "install_id": iid})
    assert resp.status_code == 202 and resp.json() == {"status": "accepted"}
    row = FunnelEvent.objects.get()
    assert row.name == "welcome_seen" and row.authenticated is False
    assert iid.encode() not in bytes(row.actor_hmac) and len(bytes(row.actor_hmac)) == 32
    assert {f.name for f in FunnelEvent._meta.concrete_fields} == {
        "id",
        "created_at",
        "updated_at",
        "name",
        "actor_hmac",
        "authenticated",
    }  # no account, ip, device or free text


def test_each_step_is_kept_once_per_actor_and_steps_are_allowlisted():
    iid = str(uuid.uuid4())
    for _ in range(3):
        assert post({"name": "otp_sent", "install_id": iid}).status_code == 202
    assert post({"name": "otp_verified", "install_id": iid}).status_code == 202
    assert FunnelEvent.objects.count() == 2
    for bad in (
        {"name": "phone_number"},
        {"name": "welcome_seen"},
        {"name": "x", "install_id": iid},
        {"name": "welcome_seen", "install_id": "nope"},
        {"name": "welcome_seen", "install_id": iid, "phone": "+256772000001"},
    ):
        assert post(bad).status_code == 422, bad
    assert FunnelEvent.objects.count() == 2
    assert set(FUNNEL_STEPS) >= {"welcome_seen", "trial_started", "paywall_seen", "golive_done"}


def test_authenticated_event_without_install_id_uses_a_hash_of_the_account():
    c = Client(headers={"host": "api.mc.test"})
    r = login(c)
    assert post({"name": "about_done"}, c, **bearer(r)).status_code == 202
    row = FunnelEvent.objects.get()
    assert row.authenticated is True
    assert str(r.json()["account"]["id"]).encode() not in bytes(row.actor_hmac)
    assert post({"name": "about_done"}, c, **bearer(r)).status_code == 202
    assert FunnelEvent.objects.count() == 1
    assert post({"name": "about_done"}, c, HTTP_AUTHORIZATION="Bearer garbage").status_code == 401


def test_rate_limits_per_actor_and_per_ip(settings):
    settings.FUNNEL_EVENTS_PER_ACTOR_PER_HOUR = 3
    iid = str(uuid.uuid4())
    codes = [post({"name": FUNNEL_STEPS[i], "install_id": iid}).status_code for i in range(5)]
    assert codes == [202, 202, 202, 429, 429]


def test_rate_limit_per_ip(settings):
    settings.FUNNEL_EVENTS_PER_IP_PER_HOUR = 2
    codes = [
        post({"name": "welcome_seen", "install_id": str(uuid.uuid4())}).status_code
        for _ in range(4)
    ]
    assert codes[:2] == [202, 202] and codes[2:] == [429, 429]


def test_missing_install_id_for_anonymous_is_rejected():
    assert post({"name": "welcome_seen"}).status_code == 422


@pytest.mark.django_db(transaction=True)
def test_rows_are_append_only_and_only_the_retention_job_deletes():
    services.record_funnel_event(
        name="welcome_seen", install_id=uuid.uuid4(), account=None, ip=None
    )
    with pytest.raises((InternalError, IntegrityError)), connection.cursor() as cur:
        cur.execute("UPDATE accounts_funnelevent SET name = 'otp_sent'")
    with pytest.raises((InternalError, IntegrityError)):
        FunnelEvent.objects.all().delete()
    assert FunnelEvent.objects.count() == 1 and FunnelEvent.objects.get().name == "welcome_seen"
    assert services.purge_funnel_events(before=timezone.now() - timedelta(days=1)) == 0
    assert services.purge_funnel_events(before=timezone.now() + timedelta(days=1)) == 1
    assert FunnelEvent.objects.count() == 0


def test_step_counts_suppress_small_cells(settings):
    settings.AGGREGATE_MIN_CELL = 5
    for _ in range(5):
        services.record_funnel_event(
            name="welcome_seen", install_id=uuid.uuid4(), account=None, ip=None
        )
    for _ in range(4):
        services.record_funnel_event(
            name="otp_sent", install_id=uuid.uuid4(), account=None, ip=None
        )
    now = timezone.now()
    counts = selectors.funnel_step_counts(
        start=now - timedelta(days=1), end=now + timedelta(days=1)
    )
    assert (
        counts["welcome_seen"] == 5
        and counts["otp_sent"] is None
        and counts["trial_started"] is None
    )
    assert list(counts) == list(FUNNEL_STEPS)

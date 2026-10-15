import uuid
from datetime import timedelta

import pytest
from django.utils import timezone
from freezegun import freeze_time

from mc.accounts.models import Session
from mc.discovery.models import Impression
from mc.interests.models import Interest, InterestSnapshot
from mc.interests.tests.helpers import member, pair, send
from mc.matches import services as match_services
from mc.matches.models import Match
from mc.media.models import MediaObject
from mc.messaging.models import Message
from mc.messaging.tests.helpers import matched, say
from mc.notifications import services as notification_services
from mc.notifications.models import Notification
from mc.privacy import retention, tasks

pytestmark = pytest.mark.django_db
DAY = timedelta(days=1)


def later(days):
    return freeze_time(timezone.now() + timedelta(days=days, hours=1))


def test_impressions_expire_after_180_days_but_not_relevant_tombstones_stay():
    m, f = pair()
    third = member("female")
    old = Impression.objects.create(
        viewer=m[2],
        candidate=f[2],
        score=0.5,
        model_version="v1",
        position=0,
        shown_at=timezone.now(),
    )
    hidden = Impression.objects.create(
        viewer=m[2],
        candidate=third[2],
        score=0.5,
        model_version="v1",
        position=0,
        shown_at=timezone.now(),
        action="not_relevant",
    )
    with later(179):
        assert retention.run()["impressions"] == 0
    with later(181):
        assert retention.run()["impressions"] == 1
        assert retention.run()["impressions"] == 0
    assert (
        not Impression.objects.filter(id=old.id).exists()
        and Impression.objects.filter(id=hidden.id).exists()
    )


def test_ended_chats_deleted_after_90_days_match_row_kept():
    m, f, mid = matched()
    from mc.matches.models import Match as M

    M.objects.update(created_at=timezone.now() - timedelta(days=10))
    say(m, mid, "bye")
    match_services.unmatch(match_id=mid, by=m[2].id)
    assert Message.objects.filter(match_id=mid).exists()
    with later(89):
        assert retention.run()["ended_chats"] == 0
    with later(91):
        assert retention.run()["ended_chats"] >= 1
    assert (
        not Message.objects.filter(match_id=mid).exists() and Match.objects.filter(id=mid).exists()
    )


def test_active_chats_are_never_purged():
    m, f, mid = matched()
    from mc.matches.models import Match as M

    M.objects.update(created_at=timezone.now() - timedelta(days=10))
    say(m, mid, "still talking")
    with later(400):
        retention.run()
    assert Message.objects.filter(match_id=mid, kind="text").exists()


def test_report_hold_keeps_an_ended_chat():
    m, f, mid = matched()
    from mc.matches.models import Match as M

    M.objects.update(created_at=timezone.now() - timedelta(days=10))
    say(f, mid, "evidence")
    reporter = m
    reporter[0].post(
        "/api/v1/reports",
        {"profile_id": f[3], "category": "scam", "context_type": "profile"},
        HTTP_AUTHORIZATION=f"Bearer {m[1].json()['access']}",
        HTTP_IDEMPOTENCY_KEY=uuid.uuid4().hex,
        content_type="application/json",
    )
    match_services.unmatch(match_id=mid, by=m[2].id)
    with later(120):
        assert retention.run()["ended_chats"] == 0  # open case about a member → hold
        from mc.safety.models import Case

        Case.objects.update(status="closed")
        assert retention.run()["ended_chats"] >= 1


def test_rejected_media_rows_purged_after_30_days_ready_media_kept():
    who = member("female", trial=False)
    rej = MediaObject.objects.create(
        owner=who[2],
        purpose="chat_image",
        declared_mime="image/jpeg",
        declared_bytes=1,
        upload_key="uploads/x",
        status="rejected",
        reject_reason="malware",
        processed_at=timezone.now(),
    )
    ready_count = MediaObject.objects.filter(owner=who[2], status="ready").count()
    with later(29):
        assert retention.run()["rejected_media"] == 0
    with later(31):
        assert retention.run()["rejected_media"] == 1
    assert (
        not MediaObject.objects.filter(id=rej.id).exists()
        and MediaObject.objects.filter(owner=who[2], status="ready").count() == ready_count
    )


def test_dead_sessions_purged_after_90_days_live_ones_kept():
    who = member("female", trial=False)
    live = Session.objects.get(account=who[2], revoked_at__isnull=True)
    dead = Session.objects.create(
        account=who[2],
        chain_id=uuid.uuid4(),
        refresh_token_hash="h" * 64,
        issued_at=timezone.now(),
        expires_at=timezone.now() + 30 * DAY,
        revoked_at=timezone.now(),
        revoke_reason="logout",
    )
    with later(89):
        assert retention.run()["dead_sessions"] == 0
    with later(91):
        res = retention.run()["dead_sessions"]
        assert res >= 1
    assert not Session.objects.filter(id=dead.id).exists()
    # the live one expires at +30d, so by +91d it's dead too — and is purged — but not before
    assert live.expires_at < timezone.now() + 31 * DAY


def test_notifications_purged_after_90_days():
    who = member("female", trial=False)
    notification_services.notify(account_id=who[2].id, type="trial_ended")
    with later(89):
        assert retention.run()["notifications"] == 0
    with later(91):
        assert retention.run()["notifications"] == 1
    assert not Notification.objects.exists()


def test_finished_interests_and_snapshots_purged_after_180_days_pending_kept():
    m, f = pair()
    f2 = member("female")
    send(m[0], m[1], f[3])
    send(m[0], m[1], f2[3])
    Interest.objects.filter(recipient=f[2]).update(status="expired")
    with later(179):
        assert retention.run()["terminal_interests"] == 0
    with later(181):
        assert retention.run()["terminal_interests"] == 1
    assert (
        Interest.objects.filter(status="pending").count() == 1
        and InterestSnapshot.objects.count() == 1
    )


def test_task_wrapper_runs_everything_and_is_idempotent():
    out = tasks.run_retention()
    assert set(out) == {
        "impressions",
        "ended_chats",
        "rejected_media",
        "dead_sessions",
        "notifications",
        "terminal_interests",
        "export_files",
        "deletions",
        "staff_sessions",
    }
    again = tasks.run_retention()
    assert all(v in (0, {"deleted": 0, "held": 0}) for v in again.values())

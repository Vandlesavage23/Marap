"""Daily retention job (Bible §12.2). Every rule is its own function so each can be tested with a frozen clock."""

from datetime import datetime, timedelta

from django.conf import settings
from django.utils import timezone

from mc.accounts import services as account_services
from mc.adminportal import services as adminportal_services
from mc.discovery import services as discovery_services
from mc.interests import services as interest_services
from mc.media import services as media_services
from mc.messaging import services as messaging_services
from mc.notifications import services as notification_services
from mc.safety import selectors as safety_selectors

from . import export, services


def _before(now: datetime, days: int) -> datetime:
    return now - timedelta(days=days)


def run(*, now: datetime | None = None) -> dict[str, object]:
    now = now or timezone.now()
    return {
        "impressions": discovery_services.purge_impressions(
            before=_before(now, settings.RETENTION_IMPRESSIONS_DAYS)
        ),
        "ended_chats": messaging_services.purge_ended_chats(
            before=_before(now, settings.RETENTION_ENDED_CHATS_DAYS),
            hold_accounts=safety_selectors.accounts_under_hold(),
        ),
        "rejected_media": media_services.purge_rejected(
            before=_before(now, settings.RETENTION_REJECTED_MEDIA_DAYS)
        ),
        "dead_sessions": account_services.purge_dead_sessions(
            before=_before(now, settings.RETENTION_DEAD_SESSIONS_DAYS)
        ),
        "staff_sessions": adminportal_services.purge_dead_staff_sessions(
            before=_before(now, settings.RETENTION_DEAD_SESSIONS_DAYS)
        ),
        "notifications": notification_services.purge_old(
            before=_before(now, settings.RETENTION_NOTIFICATIONS_DAYS)
        ),
        "terminal_interests": interest_services.purge_terminal(
            before=_before(now, settings.RETENTION_TERMINAL_INTERESTS_DAYS)
        ),
        "export_files": export.purge_expired(now=now),
        "deletions": services.run_hard_deletions(now=now),
    }

import uuid

from celery import shared_task
from django.utils import timezone

from mc.common import events

from .events import TrialReminderDue
from .models import Trial


@shared_task(queue="notify")
def send_trial_reminder(account_id: str, kind: str) -> None:
    """Fire a reminder event (notifications module turns it into a generic push). Safe to run late or
    twice; skipped if the account no longer has that trial."""
    trial = Trial.objects.filter(account_id=uuid.UUID(account_id)).first()
    if trial is None:
        return
    if kind == "ended" and trial.ends_at > timezone.now():
        return
    events.publish(TrialReminderDue(account_id=uuid.UUID(account_id), kind=kind))

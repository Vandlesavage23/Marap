from celery import shared_task

from . import enforcement


@shared_task(queue="default")
def lift_expired_suspensions() -> int:
    return enforcement.lift_expired_suspensions()

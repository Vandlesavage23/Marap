from celery import shared_task

from . import services


@shared_task(queue="default")
def expire_interests() -> int:
    return services.expire_interests()

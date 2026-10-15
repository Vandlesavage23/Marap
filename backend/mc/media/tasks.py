import uuid

from celery import shared_task

from . import services


@shared_task(queue="media", autoretry_for=(Exception,), retry_backoff=True, max_retries=3)
def process_media(media_id: str) -> None:
    services.process_media(media_id=uuid.UUID(media_id))

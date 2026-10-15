from celery import shared_task

from . import services
from .providers import get_identity_provider


@shared_task(queue="default")
def poll_stale_attempts() -> int:
    return services.poll_stale_attempts()


@shared_task(queue="default", autoretry_for=(Exception,), retry_backoff=True, max_retries=5)
def delete_vendor_images(vendor_job_id: str) -> None:
    get_identity_provider().request_image_deletion(job_id=vendor_job_id)

import uuid

from celery import shared_task

from . import services


@shared_task(queue="billing", autoretry_for=(Exception,), retry_backoff=True, max_retries=5)
def process_event(event_id: str) -> None:
    services.process_event(event_id=uuid.UUID(event_id))


@shared_task(queue="billing")
def retry_failed() -> int:
    return services.retry_failed()


@shared_task(queue="billing")
def expire_purchases() -> int:
    return services.expire_purchases()


@shared_task(queue="billing")
def sweep_pending_web() -> dict[str, int]:
    from . import reconcile

    return reconcile.sweep_pending_web()


@shared_task(queue="billing")
def nightly_reconciliation() -> dict:
    from . import reconcile

    reconcile.reconcile_google()
    return reconcile.nightly_report()

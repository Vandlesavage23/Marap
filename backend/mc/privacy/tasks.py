from celery import shared_task

from . import services


@shared_task(queue="default")
def run_hard_deletions() -> dict[str, int]:
    return services.run_hard_deletions()


@shared_task(queue="default", autoretry_for=(Exception,), retry_backoff=True, max_retries=3)
def build_export(request_id: str) -> None:
    import uuid

    from . import export

    export.build(request_id=uuid.UUID(request_id))


@shared_task(queue="default")
def purge_expired_exports() -> int:
    from . import export

    return export.purge_expired()

from django.apps import AppConfig


class CommonConfig(AppConfig):
    name = "mc.common"
    label = "common"

    def ready(self) -> None:
        from celery.signals import before_task_publish
        from django.conf import settings

        from . import queues, tracing

        before_task_publish.connect(queues.stamp_enqueued, weak=False)
        tracing.setup_tracing(settings)

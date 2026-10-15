from django.apps import AppConfig


class NotificationsConfig(AppConfig):
    name = "mc.notifications"
    label = "notifications"

    def ready(self) -> None:
        from . import handlers  # noqa: F401

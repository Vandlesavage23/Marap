from django.apps import AppConfig


class ProfilesConfig(AppConfig):
    name = "mc.profiles"
    label = "profiles"

    def ready(self) -> None:
        from . import handlers  # noqa: F401  (registers event subscribers)

from django.apps import AppConfig


class ProfilesConfig(AppConfig):
    name = "mc.profiles"
    label = "profiles"

    def ready(self) -> None:
        from mc.media.policies import register_viewer_policy

        from . import handlers  # noqa: F401  (registers event subscribers)
        from .policies import photo_media_viewer_policy

        register_viewer_policy("profile_photo", photo_media_viewer_policy)

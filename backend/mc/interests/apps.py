from django.apps import AppConfig


class InterestsConfig(AppConfig):
    name = "mc.interests"
    label = "interests"

    def ready(self) -> None:
        from mc.media.policies import register_viewer_policy

        from .policies import interest_photo_policy

        register_viewer_policy("profile_photo", interest_photo_policy)

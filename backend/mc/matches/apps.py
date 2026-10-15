from django.apps import AppConfig


class MatchesConfig(AppConfig):
    name = "mc.matches"
    label = "matches"

    def ready(self) -> None:
        from mc.media.policies import register_viewer_policy

        from .policies import match_photo_policy

        register_viewer_policy("profile_photo", match_photo_policy)

from django.apps import AppConfig


class MessagingConfig(AppConfig):
    name = "mc.messaging"
    label = "messaging"

    def ready(self) -> None:
        from mc.media.policies import register_viewer_policy

        from . import handlers  # noqa: F401
        from .policies import chat_media_policy

        register_viewer_policy("chat_image", chat_media_policy)
        register_viewer_policy("voice_note", chat_media_policy)

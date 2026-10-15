from django.apps import AppConfig


class QuestionnaireConfig(AppConfig):
    name = "mc.questionnaire"
    label = "questionnaire"

    def ready(self) -> None:
        from . import handlers  # noqa: F401

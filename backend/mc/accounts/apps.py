from django.apps import AppConfig


class AccountsConfig(AppConfig):
    name = "mc.accounts"
    label = "accounts"

    def ready(self) -> None:
        from . import schema  # noqa: F401  (registers the OpenAPI auth extension)

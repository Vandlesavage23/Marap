"""Transactional email adapter (Bible §3.3 SES). Bodies may contain one-time codes: never log them."""

from typing import ClassVar, Protocol

from django.conf import settings
from django.utils.module_loading import import_string

from mc.common.errors import ProviderError


class EmailProvider(Protocol):
    def send(self, *, to: str, subject: str, body: str) -> None: ...


class FakeEmail:
    outbox: ClassVar[list[tuple[str, str, str]]] = []
    fail: ClassVar[bool] = False

    def send(self, *, to: str, subject: str, body: str) -> None:
        if FakeEmail.fail:
            raise ProviderError("email provider unavailable")
        FakeEmail.outbox.append((to, subject, body))

    @classmethod
    def reset(cls) -> None:
        cls.outbox.clear()
        cls.fail = False


class SesEmail:  # pragma: no cover - needs AWS
    """AWS SES. UNVERIFIED until the domain/identity is set up (MC-020/MC-124)."""

    def send(self, *, to: str, subject: str, body: str) -> None:
        import boto3

        try:
            boto3.client("ses", region_name=settings.AWS_REGION).send_email(
                Source=settings.EMAIL_FROM,
                Destination={"ToAddresses": [to]},
                Message={"Subject": {"Data": subject}, "Body": {"Text": {"Data": body}}},
            )
        except Exception as exc:
            raise ProviderError("email provider error") from exc


def get_email_provider() -> EmailProvider:
    return import_string(settings.EMAIL_PROVIDER)()

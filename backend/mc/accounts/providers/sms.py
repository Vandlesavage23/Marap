"""SMS adapter interface (Bible §11.4). Vendor calls happen only in services/tasks, never views.
The message body contains OTP codes: it must never be logged."""

import json
import urllib.parse
import urllib.request
from typing import ClassVar, Protocol

from django.conf import settings
from django.utils.module_loading import import_string

from mc.common.errors import ProviderError


class SmsProvider(Protocol):
    def send(self, *, to_e164: str, body: str) -> None: ...


class FakeSms:
    """Records messages in memory (tests/local). `FakeSms.outbox` holds (to, body)."""

    outbox: ClassVar[list[tuple[str, str]]] = []
    fail: ClassVar[bool] = False

    def send(self, *, to_e164: str, body: str) -> None:
        if FakeSms.fail:
            raise ProviderError("sms provider unavailable")
        FakeSms.outbox.append((to_e164, body))

    @classmethod
    def reset(cls) -> None:
        cls.outbox.clear()
        cls.fail = False


class AfricasTalkingSms:
    """Default real provider (A). Credentials come from settings/Secrets Manager only."""

    url = "https://api.africastalking.com/version1/messaging"

    def send(self, *, to_e164: str, body: str) -> None:
        data = urllib.parse.urlencode(
            {
                "username": settings.AT_USERNAME,
                "to": to_e164,
                "message": body,
                **({"from": settings.AT_SENDER_ID} if settings.AT_SENDER_ID else {}),
            }
        ).encode()
        req = urllib.request.Request(
            self.url,
            data=data,
            headers={"apiKey": settings.AT_API_KEY, "Accept": "application/json"},
        )
        try:
            with urllib.request.urlopen(req, timeout=10) as resp:
                payload = json.loads(resp.read())
        except Exception as exc:
            raise ProviderError("sms provider error") from exc
        recipients = payload.get("SMSMessageData", {}).get("Recipients", [])
        if not recipients or recipients[0].get("statusCode") not in (100, 101, 102):
            raise ProviderError("sms provider rejected message")


def get_sms_provider() -> SmsProvider:
    return import_string(settings.SMS_PROVIDER)()

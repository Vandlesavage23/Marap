"""Push adapter (FCM; APNs via FCM). Messages are generic and ID-only (CLAUDE.md rule 10): the body is
never a name, message text or description."""

import json
import time
import urllib.parse
import urllib.request
from dataclasses import dataclass, field
from typing import ClassVar, Protocol

import jwt
from django.conf import settings
from django.utils.module_loading import import_string

from mc.common.errors import ProviderError


class InvalidToken(Exception):
    """The push token is no longer valid (uninstalled / rotated) → prune it."""


@dataclass(frozen=True)
class PushMessage:
    type: str
    data: dict[str, str] = field(default_factory=dict)  # ids only
    title: str = "Marriage Connect"
    body: str = ""


class PushProvider(Protocol):
    def send(self, *, platform: str, token: str, message: PushMessage) -> None: ...


class FakePush:
    sent: ClassVar[list[tuple[str, str, PushMessage]]] = []
    invalid_tokens: ClassVar[set[str]] = set()
    fail: ClassVar[bool] = False

    def send(self, *, platform: str, token: str, message: PushMessage) -> None:
        if FakePush.fail:
            raise ProviderError("push unavailable")
        if token in FakePush.invalid_tokens:
            raise InvalidToken(token)
        FakePush.sent.append((platform, token, message))

    @classmethod
    def reset(cls) -> None:
        cls.sent.clear()
        cls.invalid_tokens.clear()
        cls.fail = False


class FcmPush:
    """FCM HTTP v1. UNVERIFIED against Firebase (needs a project); credentials from Secrets Manager only."""

    scope = "https://www.googleapis.com/auth/firebase.messaging"
    _token: ClassVar[tuple[str, float] | None] = None

    def _access_token(self) -> str:  # pragma: no cover - needs Google
        if FcmPush._token and FcmPush._token[1] > time.time() + 60:
            return FcmPush._token[0]
        sa = json.loads(settings.FCM_SERVICE_ACCOUNT_JSON)
        now = int(time.time())
        assertion = jwt.encode(
            {
                "iss": sa["client_email"],
                "scope": self.scope,
                "aud": sa["token_uri"],
                "iat": now,
                "exp": now + 3600,
            },
            sa["private_key"],
            algorithm="RS256",
        )
        body = urllib.parse.urlencode(
            {"grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer", "assertion": assertion}
        ).encode()
        with urllib.request.urlopen(  # noqa: S310
            urllib.request.Request(sa["token_uri"], data=body),  # noqa: S310
            timeout=10,
        ) as resp:
            data = json.loads(resp.read())
        FcmPush._token = (data["access_token"], time.time() + int(data.get("expires_in", 3600)))
        return FcmPush._token[0]

    def send(
        self, *, platform: str, token: str, message: PushMessage
    ) -> None:  # pragma: no cover - needs Google
        payload = {
            "message": {
                "token": token,
                "data": {"type": message.type, **message.data},
                "notification": {"title": message.title, "body": message.body},
                "android": {"priority": "high"},
                "apns": {"headers": {"apns-priority": "10"}},
            }
        }
        req = urllib.request.Request(
            f"https://fcm.googleapis.com/v1/projects/{settings.FCM_PROJECT_ID}/messages:send",
            data=json.dumps(payload).encode(),
            headers={
                "Authorization": f"Bearer {self._access_token()}",
                "Content-Type": "application/json",
            },
        )
        try:
            urllib.request.urlopen(req, timeout=10)  # noqa: S310
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode(errors="ignore")
            if exc.code in (400, 404) and (
                "UNREGISTERED" in detail or "INVALID_ARGUMENT" in detail
            ):
                raise InvalidToken(token) from exc
            raise ProviderError("push provider error") from exc
        except OSError as exc:
            raise ProviderError("push provider error") from exc


def get_push_provider() -> PushProvider:
    return import_string(settings.PUSH_PROVIDER)()

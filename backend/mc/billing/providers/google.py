"""Google Play Billing: purchase-token verification, acknowledgement and Real-time Developer Notifications.

* Tokens are verified server-side via `purchases.subscriptionsv2.get`; our member id travels as
  `obfuscatedExternalAccountId` and must match the caller.
* RTDN arrives as a Pub/Sub push with an OIDC bearer token; we verify issuer, audience and the expected service
  account, then re-read the subscription from Google (state-based, so replays/out-of-order are harmless).

STATUS: logic tested against fakes; NOT yet run against Google (needs Play Console, MC-007). `GoogleApi` is the
real HTTP client seam (service-account OAuth) and is exercised only in staging.
"""

import base64
import hashlib
import json
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import UTC, datetime
from typing import Any, ClassVar, Protocol

import jwt
from django.conf import settings
from django.utils.module_loading import import_string

from mc.common.errors import ProviderError, Unauthenticated, ValidationFailed

JWKS_URL = "https://www.googleapis.com/oauth2/v3/certs"
STATES_WITH_ACCESS = {
    "SUBSCRIPTION_STATE_ACTIVE",
    "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
    "SUBSCRIPTION_STATE_CANCELED",
}

# RTDN SubscriptionNotification types
RENEWED, CANCELED, PURCHASED, REVOKED, EXPIRED = 2, 3, 4, 12, 13
RECOVERED, RESTARTED, DEFERRED, ON_HOLD, GRACE, PAUSED = 1, 7, 9, 5, 6, 10


def token_key(purchase_token: str) -> str:
    """Stable, short purchase key derived from the token (the token itself is stored encrypted)."""
    return hashlib.sha256(purchase_token.encode()).hexdigest()


def parse_time(value: str | None) -> datetime | None:
    if not value:
        return None
    return datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(UTC)


class PlayApi(Protocol):
    def get_subscription(self, purchase_token: str) -> dict[str, Any]: ...

    def acknowledge(self, *, product_id: str, purchase_token: str) -> None: ...


class FakePlayApi:
    """Scriptable Play API for tests/local: `subscriptions[token]` holds the v2 resource."""

    subscriptions: ClassVar[dict[str, dict[str, Any]]] = {}
    acknowledged: ClassVar[list[str]] = []
    fail: ClassVar[bool] = False

    def get_subscription(self, purchase_token: str) -> dict[str, Any]:
        if FakePlayApi.fail:
            raise ProviderError("play unavailable")
        try:
            return FakePlayApi.subscriptions[purchase_token]
        except KeyError as exc:
            raise ValidationFailed("Unknown purchase token.") from exc

    def acknowledge(self, *, product_id: str, purchase_token: str) -> None:
        FakePlayApi.acknowledged.append(purchase_token)
        if purchase_token in FakePlayApi.subscriptions:
            FakePlayApi.subscriptions[purchase_token]["acknowledgementState"] = (
                "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED"
            )

    @classmethod
    def reset(cls) -> None:
        cls.subscriptions.clear()
        cls.acknowledged.clear()
        cls.fail = False


class GooglePlayStore:  # pragma: no cover - needs Google
    """Real client: OAuth2 service-account assertion → androidpublisher v3."""

    _token: ClassVar[tuple[str, float] | None] = None
    base = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications"

    def _access_token(self) -> str:
        if self._token and self._token[1] > time.time() + 60:
            return self._token[0]
        sa = json.loads(settings.GOOGLE_SERVICE_ACCOUNT_JSON)
        now = int(time.time())
        assertion = jwt.encode(
            {"iss": sa["client_email"], "scope": "https://www.googleapis.com/auth/androidpublisher",
             "aud": sa["token_uri"], "iat": now, "exp": now + 3600},
            sa["private_key"], algorithm="RS256",
        )  # fmt: skip
        body = urllib.parse.urlencode(
            {"grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer", "assertion": assertion}
        ).encode()
        with urllib.request.urlopen(
            urllib.request.Request(sa["token_uri"], data=body), timeout=10
        ) as resp:
            data = json.loads(resp.read())
        GooglePlayStore._token = (
            data["access_token"],
            time.time() + int(data.get("expires_in", 3600)),
        )
        return GooglePlayStore._token[0]

    def _call(self, url: str, data: bytes | None = None) -> dict[str, Any]:
        req = urllib.request.Request(
            url,
            data=data,
            headers={
                "Authorization": f"Bearer {self._access_token()}",
                "Content-Type": "application/json",
            },
        )
        try:
            with urllib.request.urlopen(req, timeout=10) as resp:
                body = resp.read()
                return json.loads(body) if body else {}
        except urllib.error.HTTPError as exc:
            if exc.code in (400, 404, 410):
                raise ValidationFailed("Unknown purchase token.") from exc
            raise ProviderError("play provider error") from exc
        except OSError as exc:
            raise ProviderError("play provider error") from exc

    def get_subscription(self, purchase_token: str) -> dict[str, Any]:
        return self._call(
            f"{self.base}/{settings.GOOGLE_PACKAGE_NAME}/purchases/subscriptionsv2/tokens/{urllib.parse.quote(purchase_token)}"
        )

    def acknowledge(self, *, product_id: str, purchase_token: str) -> None:
        self._call(
            f"{self.base}/{settings.GOOGLE_PACKAGE_NAME}/purchases/subscriptions/{product_id}/tokens/{urllib.parse.quote(purchase_token)}:acknowledge",
            data=b"{}",
        )


def get_play_api() -> PlayApi:
    return import_string(settings.STORE_PROVIDER_GOOGLE)()


# ---- RTDN authentication ---------------------------------------------------------------------
class JwksClient(Protocol):
    def get_signing_key_from_jwt(self, token: str) -> Any: ...


_jwks: JwksClient | None = None


def _default_jwks() -> JwksClient:  # pragma: no cover - needs network
    global _jwks
    if _jwks is None:
        _jwks = jwt.PyJWKClient(JWKS_URL, cache_keys=True)
    return _jwks


def verify_pubsub_oidc(
    authorization: str, *, jwks_client: JwksClient | None = None
) -> dict[str, Any]:
    """Verify the Pub/Sub push's `Authorization: Bearer <OIDC JWT>`: Google-signed, right audience, and minted for
    OUR push service account. Raises Unauthenticated otherwise."""
    if not authorization.lower().startswith("bearer "):
        raise Unauthenticated()
    token = authorization.split(" ", 1)[1].strip()
    if not settings.GOOGLE_RTDN_AUDIENCE or not settings.GOOGLE_RTDN_SERVICE_ACCOUNT:
        raise Unauthenticated()
    try:
        key = (jwks_client or _default_jwks()).get_signing_key_from_jwt(token)
        claims: dict[str, Any] = jwt.decode(
            token, key.key, algorithms=["RS256"], audience=settings.GOOGLE_RTDN_AUDIENCE
        )
    except Exception as exc:
        raise Unauthenticated() from exc
    if claims.get("iss") not in ("https://accounts.google.com", "accounts.google.com"):
        raise Unauthenticated()
    if claims.get("email") != settings.GOOGLE_RTDN_SERVICE_ACCOUNT or not claims.get(
        "email_verified"
    ):
        raise Unauthenticated()
    return claims


def decode_envelope(body: dict[str, Any]) -> tuple[str, dict[str, Any]]:
    """`(message_id, rtdn_payload)` from a Pub/Sub push body."""
    try:
        message = body["message"]
        payload = json.loads(base64.b64decode(message["data"]))
        return str(message["messageId"]), payload
    except (KeyError, ValueError, TypeError) as exc:
        raise ValidationFailed("Malformed Pub/Sub message.") from exc

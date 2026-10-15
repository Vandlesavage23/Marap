"""Staff SSO (Google Workspace / Microsoft Entra) via OpenID Connect authorization-code flow, behind an interface.

`OidcSso` is generic OIDC (discovery document + JWKS). UNVERIFIED against a real tenant (needs the company IdP)."""

import json
import secrets
import urllib.parse
import urllib.request
from dataclasses import dataclass
from typing import ClassVar, Protocol

import jwt
from django.conf import settings
from django.utils.module_loading import import_string

from mc.common.errors import ProviderError, Unauthenticated


@dataclass(frozen=True)
class SsoIdentity:
    subject: str
    email: str
    name: str
    email_verified: bool


class SsoProvider(Protocol):
    def authorization_url(self, *, state: str, nonce: str, redirect_uri: str) -> str: ...

    def exchange(self, *, code: str, redirect_uri: str, nonce: str) -> SsoIdentity: ...


class FakeSso:
    """Tests: `codes[code] = SsoIdentity(...)`; authorization_url just embeds the state."""

    codes: ClassVar[dict[str, SsoIdentity]] = {}

    def authorization_url(self, *, state: str, nonce: str, redirect_uri: str) -> str:
        return f"https://idp.fake/authorize?state={state}&nonce={nonce}"

    def exchange(self, *, code: str, redirect_uri: str, nonce: str) -> SsoIdentity:
        try:
            return FakeSso.codes[code]
        except KeyError as exc:
            raise Unauthenticated() from exc

    @classmethod
    def reset(cls) -> None:
        cls.codes.clear()


class OidcSso:  # pragma: no cover - needs an IdP
    def _discovery(self) -> dict:
        with urllib.request.urlopen(
            settings.STAFF_OIDC_ISSUER.rstrip("/") + "/.well-known/openid-configuration", timeout=10
        ) as r:
            return json.loads(r.read())

    def authorization_url(self, *, state: str, nonce: str, redirect_uri: str) -> str:
        q = urllib.parse.urlencode(
            {
                "client_id": settings.STAFF_OIDC_CLIENT_ID,
                "response_type": "code",
                "scope": "openid email profile",
                "redirect_uri": redirect_uri,
                "state": state,
                "nonce": nonce,
            }
        )
        return f"{self._discovery()['authorization_endpoint']}?{q}"

    def exchange(self, *, code: str, redirect_uri: str, nonce: str) -> SsoIdentity:
        disc = self._discovery()
        body = urllib.parse.urlencode(
            {
                "grant_type": "authorization_code",
                "code": code,
                "redirect_uri": redirect_uri,
                "client_id": settings.STAFF_OIDC_CLIENT_ID,
                "client_secret": settings.STAFF_OIDC_CLIENT_SECRET,
            }
        ).encode()
        try:
            with urllib.request.urlopen(
                urllib.request.Request(disc["token_endpoint"], data=body), timeout=10
            ) as r:
                tokens = json.loads(r.read())
            key = jwt.PyJWKClient(disc["jwks_uri"]).get_signing_key_from_jwt(tokens["id_token"]).key
            claims = jwt.decode(
                tokens["id_token"],
                key,
                algorithms=["RS256"],
                audience=settings.STAFF_OIDC_CLIENT_ID,
                issuer=disc["issuer"],
            )
        except Exception as exc:
            raise ProviderError("sso provider error") from exc
        if claims.get("nonce") != nonce:
            raise Unauthenticated()
        return SsoIdentity(
            str(claims["sub"]),
            str(claims.get("email", "")).lower(),
            str(claims.get("name", "")),
            bool(claims.get("email_verified")),
        )


def get_sso() -> SsoProvider:
    return import_string(settings.STAFF_SSO_PROVIDER)()


def new_state() -> str:
    return secrets.token_urlsafe(24)

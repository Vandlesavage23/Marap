"""Short-lived JWT access tokens (EdDSA) and opaque refresh tokens (Bible §12.1)."""

import hashlib
import secrets
import uuid
from datetime import datetime, timedelta
from typing import Any

import jwt
from django.conf import settings
from django.utils import timezone

from mc.common.errors import TokenExpired, Unauthenticated

ALGORITHM = "EdDSA"
TOKEN_SCHEMA_VERSION = 1
ISSUER = "marriage-connect"


def issue_access_token(
    *, account_id: uuid.UUID, session_id: uuid.UUID, now: datetime | None = None
) -> str:
    now = now or timezone.now()
    claims = {
        "iss": ISSUER,
        "sub": str(account_id),
        "sid": str(session_id),
        "ver": TOKEN_SCHEMA_VERSION,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(minutes=settings.ACCESS_TOKEN_MINUTES)).timestamp()),
    }
    return jwt.encode(claims, settings.MC_JWT_PRIVATE_KEY_PEM, algorithm=ALGORITHM)


def decode_access_token(token: str) -> dict[str, Any]:
    try:
        claims: dict[str, Any] = jwt.decode(
            token,
            settings.MC_JWT_PUBLIC_KEY_PEM,
            algorithms=[ALGORITHM],  # pinned: never accept `none`/HS*
            issuer=ISSUER,
            options={"require": ["exp", "sub", "sid", "iat"]},
        )
    except jwt.ExpiredSignatureError as exc:
        raise TokenExpired() from exc
    except jwt.PyJWTError as exc:
        raise Unauthenticated() from exc
    if claims.get("ver") != TOKEN_SCHEMA_VERSION:
        raise Unauthenticated()
    return claims


def new_refresh_token() -> str:
    return secrets.token_urlsafe(32)  # 256 bits


def hash_refresh_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()

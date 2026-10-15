"""RFC 6238 TOTP (SHA-1, 6 digits, 30 s step), no third-party dependency."""

import base64
import hashlib
import hmac
import secrets
import struct
import time
import urllib.parse

STEP = 30
DIGITS = 6


def new_secret() -> str:
    return base64.b32encode(secrets.token_bytes(20)).decode().rstrip("=")


def _code(secret: str, counter: int) -> str:
    key = base64.b32decode(secret + "=" * (-len(secret) % 8))
    digest = hmac.new(key, struct.pack(">Q", counter), hashlib.sha1).digest()
    offset = digest[-1] & 0x0F
    value = (struct.unpack(">I", digest[offset : offset + 4])[0] & 0x7FFFFFFF) % (10**DIGITS)
    return f"{value:0{DIGITS}d}"


def current_step(now: float | None = None) -> int:
    return int((now if now is not None else time.time()) // STEP)


def code_at(secret: str, now: float | None = None) -> str:
    return _code(secret, current_step(now))


def verify(
    secret: str, code: str, *, last_step: int = 0, now: float | None = None, window: int = 1
) -> int | None:
    """The matching time step (> `last_step`, so codes can't be replayed), or None."""
    if not code.isdigit() or len(code) != DIGITS:
        return None
    step = current_step(now)
    for s in range(step - window, step + window + 1):
        if s > last_step and hmac.compare_digest(_code(secret, s), code):
            return s
    return None


def provisioning_uri(secret: str, email: str, issuer: str = "Marriage Connect Admin") -> str:
    label = urllib.parse.quote(f"{issuer}:{email}")
    return f"otpauth://totp/{label}?secret={secret}&issuer={urllib.parse.quote(issuer)}&digits={DIGITS}&period={STEP}"

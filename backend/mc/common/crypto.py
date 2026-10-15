"""Field encryption and keyed hashes (Bible §12.1).

* `EncryptedTextField` — AES-256-GCM, fresh 96-bit nonce per write, so ciphertext differs per write.
  Stored form: ``v1:<key_id>:<base64(nonce || ciphertext+tag)>``. The key id prefix lets old rows
  decrypt after rotation. Data keys are stored *wrapped* by a KMS (`Kms.unwrap`); the plaintext data key
  is only ever held in process memory. Production uses AWS KMS (`mc-data`); local/test use `FakeKms`.
* `hmac_value()` — HMAC-SHA256 with a purpose-specific pepper for id numbers, phones, IPs.

Never log plaintext or keys. Encrypted columns cannot be filtered or ordered in SQL by design.
"""

import base64
import hashlib
import hmac
import os
from functools import lru_cache
from typing import Any, Protocol

from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from django.conf import settings
from django.db import models

CIPHER_VERSION = "v1"


class Kms(Protocol):
    def unwrap(self, wrapped: bytes) -> bytes: ...


class FakeKms:
    """Local stand-in for cloud KMS: wraps data keys with AES-256-GCM under a local master key."""

    def __init__(self, master_key: bytes) -> None:
        if len(master_key) != 32:
            raise ValueError("master key must be 32 bytes")
        self._aes = AESGCM(master_key)

    def wrap(self, data_key: bytes) -> bytes:
        nonce = os.urandom(12)
        return nonce + self._aes.encrypt(nonce, data_key, b"mc-data-key")

    def unwrap(self, wrapped: bytes) -> bytes:
        return self._aes.decrypt(wrapped[:12], wrapped[12:], b"mc-data-key")


def fake_master_key(secret: str) -> bytes:
    return hashlib.sha256(b"mc-fake-kms|" + secret.encode()).digest()


def make_dev_keyring(secret: str, key_ids: list[str]) -> dict[str, str]:
    """Deterministic wrapped data keys for local/test settings only (never for real environments)."""
    kms = FakeKms(fake_master_key(secret))
    return {
        kid: base64.b64encode(
            kms.wrap(hashlib.sha256(f"mc-dev-dek|{secret}|{kid}".encode()).digest())
        ).decode()
        for kid in key_ids
    }


def _kms() -> Kms:
    configured = getattr(settings, "MC_KMS", None)
    if configured is not None:
        return configured
    return FakeKms(fake_master_key(settings.SECRET_KEY))


@lru_cache(maxsize=32)
def _data_key(key_id: str, wrapped_b64: str) -> bytes:
    return _kms().unwrap(base64.b64decode(wrapped_b64))


def clear_key_cache() -> None:  # tests / rotation
    _data_key.cache_clear()


def _key_for(key_id: str) -> bytes:
    ring: dict[str, str] = settings.MC_DATA_KEYS
    try:
        return _data_key(key_id, ring[key_id])
    except KeyError as exc:
        raise ValueError(f"unknown data key id {key_id!r}") from exc


def encrypt_text(plaintext: str) -> str:
    key_id: str = settings.MC_DATA_KEY_CURRENT
    nonce = os.urandom(12)
    ct = AESGCM(_key_for(key_id)).encrypt(nonce, plaintext.encode(), key_id.encode())
    return f"{CIPHER_VERSION}:{key_id}:{base64.b64encode(nonce + ct).decode()}"


def decrypt_text(stored: str) -> str:
    try:
        version, key_id, payload = stored.split(":", 2)
    except ValueError as exc:
        raise ValueError("malformed ciphertext") from exc
    if version != CIPHER_VERSION:
        raise ValueError("unsupported ciphertext version")
    raw = base64.b64decode(payload)
    return AESGCM(_key_for(key_id)).decrypt(raw[:12], raw[12:], key_id.encode()).decode()


class EncryptedTextField(models.TextField):
    """Transparent AES-256-GCM encryption at rest. Use for special personal data (CLAUDE.md rule 4)."""

    description = "Text encrypted at rest with AES-256-GCM"

    def get_prep_value(self, value: Any) -> Any:
        value = super().get_prep_value(value)
        return None if value is None else encrypt_text(value)

    def from_db_value(self, value: Any, expression: Any, connection: Any) -> Any:
        return None if value is None else decrypt_text(value)

    def get_lookup(self, lookup_name: str) -> Any:
        if lookup_name != "isnull":
            raise TypeError("Encrypted fields only support isnull lookups")
        return super().get_lookup(lookup_name)


def hmac_value(value: str, *, purpose: str) -> bytes:
    """Stable HMAC-SHA256(pepper[purpose], value). Same input → same output across processes."""
    peppers: dict[str, str] = settings.MC_PEPPERS
    try:
        pepper = peppers[purpose].encode()
    except KeyError as exc:
        raise ValueError(f"no pepper configured for purpose {purpose!r}") from exc
    return hmac.new(pepper, value.encode(), hashlib.sha256).digest()


def dev_ed25519_pems(secret: str) -> tuple[str, str]:
    """Deterministic Ed25519 keypair for local/test only (real environments inject keys)."""
    from cryptography.hazmat.primitives import serialization
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

    key = Ed25519PrivateKey.from_private_bytes(
        hashlib.sha256(f"mc-dev-jwt|{secret}".encode()).digest()
    )
    private = key.private_bytes(
        serialization.Encoding.PEM,
        serialization.PrivateFormat.PKCS8,
        serialization.NoEncryption(),
    ).decode()
    public = (
        key.public_key()
        .public_bytes(serialization.Encoding.PEM, serialization.PublicFormat.SubjectPublicKeyInfo)
        .decode()
    )
    return private, public

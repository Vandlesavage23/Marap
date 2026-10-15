"""Apple App Store: StoreKit 2 signed transactions (JWS) and App Store Server Notifications v2 (Bible §11.2).

Everything Apple sends is a JWS whose header carries an `x5c` certificate chain. We trust it only if the chain
validates to a configured Apple root (`APPLE_ROOT_CERTS_PEM`, Apple Root CA - G3) and the JWS signature checks
out against the leaf key. Our `appAccountToken` (the member's account id) binds a purchase to its owner.

STATUS: logic is covered by tests that sign with a locally generated CA; NOT yet exercised against Apple's
sandbox (needs the Apple Developer account, MC-007, and sandbox purchases).
"""

import base64
import itertools
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any

import jwt
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.x509.oid import NameOID  # noqa: F401
from django.conf import settings

from mc.common.errors import ProviderError, ValidationFailed

from ..events import CANCEL, EXPIRE, GRANT, REFUND, REVOKE


def _load_roots() -> list[x509.Certificate]:
    roots = [x509.load_pem_x509_certificate(pem.encode()) for pem in settings.APPLE_ROOT_CERTS_PEM]
    if not roots:
        raise ProviderError("Apple root certificates are not configured")
    return roots


def _verify_chain(
    chain: list[x509.Certificate], roots: list[x509.Certificate], now: datetime
) -> None:
    """leaf ← intermediate(s) ← one of `roots`; every cert in date; each signed by the next."""
    root = next((r for r in roots if _issued_by(chain[-1], r)), None)
    if root is None:
        raise ValidationFailed("Untrusted Apple certificate chain.")
    full = [*chain, root]
    for cert in full:
        if not cert.not_valid_before_utc <= now <= cert.not_valid_after_utc:
            raise ValidationFailed("Expired Apple certificate.")
    for child, parent in itertools.pairwise(full):
        if not _issued_by(child, parent):
            raise ValidationFailed("Broken Apple certificate chain.")


def _issued_by(child: x509.Certificate, parent: x509.Certificate) -> bool:
    try:
        key = parent.public_key()
        assert isinstance(key, ec.EllipticCurvePublicKey)  # noqa: S101 - Apple chains are ECDSA
        key.verify(
            child.signature,
            child.tbs_certificate_bytes,
            ec.ECDSA(child.signature_hash_algorithm or hashes.SHA384()),
        )
    except Exception:
        return False
    return child.issuer == parent.subject


def verify_jws(signed: str, *, now: datetime | None = None) -> dict[str, Any]:
    """Verify an Apple JWS and return its payload."""
    now = now or datetime.now(UTC)
    try:
        header = jwt.get_unverified_header(signed)
    except jwt.PyJWTError as exc:
        raise ValidationFailed("Malformed signed payload.") from exc
    if header.get("alg") != "ES256" or not header.get("x5c"):
        raise ValidationFailed("Unsupported signed payload.")
    chain = [x509.load_der_x509_certificate(base64.b64decode(c)) for c in header["x5c"]]
    _verify_chain(chain, _load_roots(), now)
    leaf_key = (
        chain[0]
        .public_key()
        .public_bytes(serialization.Encoding.PEM, serialization.PublicFormat.SubjectPublicKeyInfo)
    )
    try:
        payload: dict[str, Any] = jwt.decode(
            signed,
            leaf_key,
            algorithms=["ES256"],
            options={"verify_exp": False, "verify_aud": False},
        )
    except jwt.PyJWTError as exc:
        raise ValidationFailed("Invalid signature.") from exc
    return payload


def _ms(value: Any) -> datetime | None:
    return datetime.fromtimestamp(int(value) / 1000, tz=UTC) if value else None


@dataclass(frozen=True)
class AppleTransaction:
    transaction_id: str
    original_transaction_id: str
    product_id: str
    purchase_date: datetime
    expires_date: datetime | None
    revocation_date: datetime | None
    account_token: uuid.UUID | None
    environment: str
    price_minor: int
    currency: str


def parse_transaction(payload: dict[str, Any]) -> AppleTransaction:
    if payload.get("bundleId") != settings.APPLE_BUNDLE_ID:
        raise ValidationFailed("Transaction is for a different app.")
    if payload.get("environment") != settings.APPLE_ENVIRONMENT:
        raise ValidationFailed("Transaction environment mismatch.")
    token = payload.get("appAccountToken")
    return AppleTransaction(
        transaction_id=str(payload["transactionId"]),
        original_transaction_id=str(payload["originalTransactionId"]),
        product_id=str(payload["productId"]),
        purchase_date=_ms(payload["purchaseDate"]) or datetime.now(UTC),
        expires_date=_ms(payload.get("expiresDate")),
        revocation_date=_ms(payload.get("revocationDate")),
        account_token=uuid.UUID(token) if token else None,
        environment=str(payload["environment"]),
        price_minor=int(payload.get("price", 0)) // 1000
        if payload.get("price")
        else 0,  # Apple prices are milli-units
        currency=str(payload.get("currency", "UGX")),
    )


def kind_for_notification(notification_type: str, subtype: str | None) -> str | None:
    """App Store Server Notifications v2 → our normalized kind (None = informational, no state change)."""
    n = notification_type
    if n in ("SUBSCRIBED", "DID_RENEW", "OFFER_REDEEMED", "RENEWAL_EXTENDED"):
        return GRANT
    if n == "DID_CHANGE_RENEWAL_STATUS":
        return (
            CANCEL
            if subtype == "AUTO_RENEW_DISABLED"
            else GRANT
            if subtype == "AUTO_RENEW_ENABLED"
            else None
        )
    if n in ("EXPIRED", "GRACE_PERIOD_EXPIRED"):
        return EXPIRE
    if n == "REFUND":
        return REFUND
    if n == "REVOKE":
        return REVOKE
    return None  # DID_FAIL_TO_RENEW, PRICE_INCREASE, TEST, ...


class AppleStore:
    """Thin seam for calls to the App Store Server API (subscription status). Needs an App Store Connect API key;
    injected/faked in tests. Not required for JWS verification."""

    def get_transaction(
        self, transaction_id: str
    ) -> dict[str, Any]:  # pragma: no cover - needs Apple
        raise ProviderError(
            "App Store Server API client is configured in MC-098 follow-up (needs API key)"
        )

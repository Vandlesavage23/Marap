"""A throwaway 'Apple' PKI for tests: root (P-384) → intermediate (P-256) → leaf (P-256), plus JWS signing."""

import base64
import time
import uuid
from datetime import UTC, datetime, timedelta

import jwt
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.x509.oid import NameOID


def _name(cn: str) -> x509.Name:
    return x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, cn)])


def _cert(subject, issuer, pub, signer, *, ca=False, days=365, start=None):
    start = start or datetime.now(UTC) - timedelta(days=1)
    return (
        x509.CertificateBuilder()
        .subject_name(_name(subject)).issuer_name(_name(issuer)).public_key(pub)
        .serial_number(x509.random_serial_number()).not_valid_before(start).not_valid_after(start + timedelta(days=days))
        .add_extension(x509.BasicConstraints(ca=ca, path_length=None), critical=True)
        .sign(signer, hashes.SHA384() if isinstance(signer.curve, ec.SECP384R1) else hashes.SHA256())
    )  # fmt: skip


class FakeApplePki:
    def __init__(self, *, leaf_days=365, leaf_start=None):
        self.root_key = ec.generate_private_key(ec.SECP384R1())
        self.int_key = ec.generate_private_key(ec.SECP256R1())
        self.leaf_key = ec.generate_private_key(ec.SECP256R1())
        self.root = _cert(
            "Test Apple Root",
            "Test Apple Root",
            self.root_key.public_key(),
            self.root_key,
            ca=True,
            days=3650,
        )
        self.inter = _cert(
            "Test Apple Intermediate",
            "Test Apple Root",
            self.int_key.public_key(),
            self.root_key,
            ca=True,
        )
        self.leaf = _cert(
            "Test Leaf",
            "Test Apple Intermediate",
            self.leaf_key.public_key(),
            self.int_key,
            days=leaf_days,
            start=leaf_start,
        )

    @property
    def root_pem(self) -> str:
        return self.root.public_bytes(serialization.Encoding.PEM).decode()

    def sign(self, payload: dict, *, chain=None) -> str:
        certs = chain or [self.leaf, self.inter]
        x5c = [base64.b64encode(c.public_bytes(serialization.Encoding.DER)).decode() for c in certs]
        return jwt.encode(payload, self.leaf_key, algorithm="ES256", headers={"x5c": x5c})


def ms(dt: datetime) -> int:
    return int(dt.timestamp() * 1000)


def transaction_payload(
    *,
    account_id,
    product_id="ug.marriageconnect.membership_1m",
    txn=None,
    original=None,
    purchase=None,
    days=30,
    token="default",
    revoked=None,
    **kw,
):
    purchase = purchase or datetime.now(UTC)
    payload = {
        "transactionId": txn or str(uuid.uuid4().int)[:12],
        "originalTransactionId": original or "1000000123456789",
        "bundleId": "ug.marriageconnect.app",
        "productId": product_id,
        "purchaseDate": ms(purchase),
        "expiresDate": ms(purchase + timedelta(days=days)),
        "type": "Auto-Renewable Subscription",
        "environment": "Sandbox",
        "appAccountToken": str(account_id) if token == "default" else token,
        "currency": "UGX",
        "price": 20000000,
    }
    if revoked:
        payload["revocationDate"] = ms(revoked)
        payload["revocationReason"] = 1
    payload.update(kw)
    return payload


def notification_payload(pki, *, ntype, subtype=None, txn_payload=None, uuid_=None, signed_at=None):
    return pki.sign(
        {
            "notificationType": ntype, "subtype": subtype, "notificationUUID": uuid_ or str(uuid.uuid4()),
            "signedDate": ms(signed_at or datetime.now(UTC)),
            "data": {"bundleId": "ug.marriageconnect.app", "environment": "Sandbox",
                     "signedTransactionInfo": pki.sign(txn_payload) if txn_payload else None},
            "version": "2.0",
        }
    )  # fmt: skip


__all__ = ["FakeApplePki", "ms", "notification_payload", "time", "transaction_payload"]

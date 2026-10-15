import hashlib
import hmac
import json
from collections.abc import Mapping
from datetime import date
from typing import Any, ClassVar

from django.conf import settings

from .base import VendorResult


class FakeIdentityProvider:
    """Deterministic fake for tests/local. Callbacks are signed with HMAC-SHA256 over the raw body
    (`X-Fake-Signature`). `jobs` lets tests script what polling returns."""

    jobs: ClassVar[dict[str, VendorResult]] = {}
    deleted: ClassVar[list[str]] = []
    header = "X-Fake-Signature"

    @classmethod
    def reset(cls) -> None:
        cls.jobs.clear()
        cls.deleted.clear()

    @staticmethod
    def sign(body: bytes) -> str:
        return hmac.new(settings.FAKE_IDENTITY_SECRET.encode(), body, hashlib.sha256).hexdigest()

    @staticmethod
    def callback_body(result: VendorResult) -> bytes:
        return json.dumps(
            {
                "job_id": result.job_id,
                "outcome": result.outcome,
                "reason": result.vendor_reason,
                "id_type": result.id_type,
                "issuing_country": result.issuing_country,
                "date_of_birth": result.date_of_birth.isoformat() if result.date_of_birth else None,
                "id_number": result.id_number,
                "document_expired": result.document_expired,
                "liveness_passed": result.liveness_passed,
                "face_match_passed": result.face_match_passed,
            }
        ).encode()

    def create_job(self, *, job_id: str, user_id: str) -> dict[str, Any]:
        return {
            "provider": "fake",
            "partner_id": "fake-partner",
            "job_id": job_id,
            "user_id": user_id,
            "signature": self.sign(job_id.encode()),
            "environment": "sandbox",
        }

    def verify_callback(self, *, body: bytes, headers: Mapping[str, str]) -> bool:
        provided = headers.get(self.header, "")
        return hmac.compare_digest(provided, self.sign(body))

    def parse_callback(self, *, body: bytes) -> VendorResult:
        d = json.loads(body)
        return VendorResult(
            job_id=d["job_id"],
            outcome=d["outcome"],
            vendor_reason=d.get("reason", ""),
            id_type=d.get("id_type", ""),
            issuing_country=d.get("issuing_country", ""),
            date_of_birth=date.fromisoformat(d["date_of_birth"])
            if d.get("date_of_birth")
            else None,
            id_number=d.get("id_number"),
            document_expired=d.get("document_expired", False),
            liveness_passed=d.get("liveness_passed", True),
            face_match_passed=d.get("face_match_passed", True),
        )

    def fetch_job_status(self, *, job_id: str) -> VendorResult | None:
        return self.jobs.get(job_id)

    def request_image_deletion(self, *, job_id: str) -> None:
        self.deleted.append(job_id)

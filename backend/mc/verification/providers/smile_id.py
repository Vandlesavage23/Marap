"""Smile ID adapter (Bible §11.1).

STATUS: written from Smile ID's public docs, NOT yet exercised against the sandbox. Confirm product
names, result codes (`reasons.SMILE_ID_REASONS`), callback fields and the signature scheme in
MC-002 / MC-030 before relying on it. Partner id / API key are server-side secrets only.
"""

import base64
import hashlib
import hmac
import json
import time
from collections.abc import Mapping
from datetime import date
from typing import Any

from django.conf import settings

from mc.common.errors import ProviderError

from .. import reasons
from .base import VendorResult

PASSED_CODES = {"0810", "1012", "0820", "0840"}


def _signature(timestamp: str) -> str:
    msg = (timestamp + settings.SMILE_ID_PARTNER_ID + "sid_request").encode()
    return base64.b64encode(
        hmac.new(settings.SMILE_ID_API_KEY.encode(), msg, hashlib.sha256).digest()
    ).decode()


class SmileIdProvider:
    def create_job(self, *, job_id: str, user_id: str) -> dict[str, Any]:
        ts = str(int(time.time() * 1000))
        return {
            "provider": "smile_id",
            "partner_id": settings.SMILE_ID_PARTNER_ID,
            "job_id": job_id,
            "user_id": user_id,
            "signature": _signature(ts),
            "timestamp": ts,
            "environment": settings.SMILE_ID_ENV,
        }

    def verify_callback(self, *, body: bytes, headers: Mapping[str, str]) -> bool:
        try:
            payload = json.loads(body)
            ts, sig = str(payload["timestamp"]), str(payload["signature"])
        except (ValueError, KeyError):
            return False
        return hmac.compare_digest(sig, _signature(ts))

    def parse_callback(self, *, body: bytes) -> VendorResult:
        d = json.loads(body)
        actions = d.get("Actions", {})
        code = str(d.get("ResultCode", ""))
        passed = actions.get("Verify_ID_Number") != "Not Verified" and (
            code in PASSED_CODES or d.get("ResultText", "").lower().startswith("pass")
        )
        dob = d.get("DOB") or d.get("dob")
        return VendorResult(
            job_id=d.get("PartnerParams", {}).get("job_id", ""),
            outcome="passed" if passed else "failed",
            vendor_reason="" if passed else reasons.map_smile_id(code),
            id_type=d.get("IDType", ""),
            issuing_country=d.get("Country", "")[:2].upper(),
            date_of_birth=date.fromisoformat(dob) if dob else None,
            id_number=d.get("IDNumber") or None,
            document_expired=actions.get("Document_Check") == "Expired",
            liveness_passed=actions.get("Liveness_Check", "Passed") == "Passed",
            face_match_passed=actions.get("Selfie_To_ID_Card_Compare", "Completed")
            != "Not Matching",
            summary={"result_code": code},
        )

    def fetch_job_status(
        self, *, job_id: str
    ) -> VendorResult | None:  # pragma: no cover - needs sandbox
        raise ProviderError("Smile ID job-status polling not implemented until MC-030")

    def request_image_deletion(self, *, job_id: str) -> None:  # pragma: no cover - needs sandbox
        raise ProviderError("Smile ID image deletion not implemented until MC-030")

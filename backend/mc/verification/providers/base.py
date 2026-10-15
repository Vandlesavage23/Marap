"""Identity-vendor interface (Bible §11). Vendor SDK/HTTP calls never happen in views."""

from collections.abc import Mapping
from dataclasses import dataclass, field
from datetime import date
from typing import Any, Protocol


@dataclass(frozen=True)
class VendorResult:
    """Normalised callback/poll outcome. `id_number` is transient: the service HMACs it and drops it."""

    job_id: str
    outcome: str  # passed | failed | needs_review | error
    vendor_reason: str = ""  # reason code already normalised (see reasons.py)
    id_type: str = ""
    issuing_country: str = ""
    date_of_birth: date | None = None
    id_number: str | None = None
    document_expired: bool = False
    liveness_passed: bool = True
    face_match_passed: bool = True
    summary: dict[str, Any] = field(default_factory=dict)  # minimal, no images / ID numbers


class IdentityProvider(Protocol):
    def create_job(self, *, job_id: str, user_id: str) -> dict[str, Any]:
        """Return the PUBLIC SDK launch params (signature, timestamp, partner id, ...). Secrets stay here."""

    def verify_callback(self, *, body: bytes, headers: Mapping[str, str]) -> bool: ...

    def parse_callback(self, *, body: bytes) -> VendorResult: ...

    def fetch_job_status(self, *, job_id: str) -> VendorResult | None:
        """Polling fallback. None = vendor has no result (yet)."""

    def request_image_deletion(self, *, job_id: str) -> None: ...

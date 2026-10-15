import json
import uuid
from datetime import date

from django.test import Client

from mc.accounts.tests.helpers import bearer, login
from mc.verification.providers.base import VendorResult
from mc.verification.providers.fake import FakeIdentityProvider

J = {"content_type": "application/json"}
CONSENTS = [
    {"kind": k, "version": "2026-01", "granted": True}
    for k in ("terms", "privacy", "data_transfer")
]


def new_user(phone="+256772000001", consents=True, client: Client | None = None):
    client = client or Client(headers={"host": "api.mc.test"})
    r = login(client, phone=phone)
    if consents:
        client.post("/api/v1/me/consents", {"consents": CONSENTS}, **bearer(r), **J)
    return client, r


def start(client, r, key=None, **body):
    return client.post(
        "/api/v1/verification/sessions",
        body,
        **bearer(r),
        HTTP_IDEMPOTENCY_KEY=key or uuid.uuid4().hex,
        **J,
    )


def result(job_id, **kw) -> VendorResult:
    base = {
        "job_id": job_id,
        "outcome": "passed",
        "id_type": "NATIONAL_ID",
        "issuing_country": "UG",
        "date_of_birth": date(1995, 5, 17),
        "id_number": "CM 9512-3456 789",
        "liveness_passed": True,
        "face_match_passed": True,
    }
    base.update(kw)
    return VendorResult(**base)


def callback(client, res: VendorResult, *, sign=True, body=None):
    body = body or FakeIdentityProvider.callback_body(res)
    headers = {"HTTP_X_FAKE_SIGNATURE": FakeIdentityProvider.sign(body) if sign else "bad"}
    return client.post(
        "/api/v1/webhooks/smile-id", body, content_type="application/json", **headers
    )


def job_id_of(resp) -> str:
    from mc.verification.models import VerificationAttempt

    return VerificationAttempt.objects.get(id=resp.json()["attempt_id"]).vendor_job_id


__all__ = ["callback", "job_id_of", "json", "new_user", "result", "start"]

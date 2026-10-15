import re
import uuid

from django.test import Client

from mc.accounts.providers.sms import FakeSms

PHONE = "+256772000001"


def last_code(to: str | None = None) -> str:
    for dest, body in reversed(FakeSms.outbox):
        if (to is None or dest == to) and (m := re.search(r"code is (\d{6})", body)):
            return m.group(1)
    raise AssertionError("no OTP sent")


def login(client: Client, phone: str = PHONE, device: dict | None = None, ip: str = "10.0.0.1"):
    client.post(
        "/api/v1/auth/otp/start", {"phone": phone}, content_type="application/json", REMOTE_ADDR=ip
    )
    body = {"phone": phone, "code": last_code(phone)}
    if device is not False:
        body["device"] = device or {"install_id": str(uuid.uuid4()), "platform": "android"}
    return client.post(
        "/api/v1/auth/otp/verify", body, content_type="application/json", REMOTE_ADDR=ip
    )


def bearer(resp) -> dict:
    return {"HTTP_AUTHORIZATION": f"Bearer {resp.json()['access']}"}

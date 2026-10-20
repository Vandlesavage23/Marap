import base64
import io
import json
import urllib.parse
from urllib.error import URLError

import pytest

from mc.accounts.providers import sms
from mc.common.errors import ProviderError


class Resp(io.BytesIO):
    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False


def capture(monkeypatch, payload=None, raise_exc=None):
    seen = {}

    def fake(req, timeout=0):
        seen["req"], seen["timeout"] = req, timeout
        if raise_exc:
            raise raise_exc
        return Resp(json.dumps(payload or {}).encode())

    monkeypatch.setattr(sms.urllib.request, "urlopen", fake)
    return seen


def test_twilio_builds_authenticated_request_and_never_leaks_credentials_in_errors(
    monkeypatch, settings
):
    settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN, settings.TWILIO_FROM = (
        "ACxx",
        "tok",
        "+15005550006",
    )
    settings.TWILIO_MESSAGING_SERVICE_SID = ""
    seen = capture(monkeypatch, {"status": "queued"})
    sms.TwilioSms().send(to_e164="+256772000001", body="Your code is 123456")
    req = seen["req"]
    assert req.full_url.endswith("/Accounts/ACxx/Messages.json") and seen["timeout"] == 10
    assert req.headers["Authorization"] == "Basic " + base64.b64encode(b"ACxx:tok").decode()
    form = urllib.parse.parse_qs(req.data.decode())
    assert form["To"] == ["+256772000001"] and form["From"] == ["+15005550006"]
    capture(monkeypatch, raise_exc=URLError("boom tok"))
    with pytest.raises(ProviderError) as e:
        sms.TwilioSms().send(to_e164="+256772000001", body="x")
    assert "tok" not in str(e.value) and "ACxx" not in str(e.value)


def test_twilio_prefers_messaging_service_rejects_failures_and_requires_config(
    monkeypatch, settings
):
    settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN, settings.TWILIO_FROM = (
        "ACxx",
        "tok",
        "",
    )
    settings.TWILIO_MESSAGING_SERVICE_SID = "MG123"
    seen = capture(monkeypatch, {"status": "queued"})
    sms.TwilioSms().send(to_e164="+256772000001", body="x")
    assert urllib.parse.parse_qs(seen["req"].data.decode())["MessagingServiceSid"] == ["MG123"]
    capture(monkeypatch, {"status": "failed", "error_code": 21211})
    with pytest.raises(ProviderError):
        sms.TwilioSms().send(to_e164="+256772000001", body="x")
    settings.TWILIO_ACCOUNT_SID = ""
    with pytest.raises(ProviderError):
        sms.TwilioSms().send(to_e164="+256772000001", body="x")


def test_africas_talking_uses_sandbox_host_only_for_sandbox_username(monkeypatch, settings):
    settings.AT_API_KEY, settings.AT_SENDER_ID = "k", ""
    ok = {"SMSMessageData": {"Recipients": [{"statusCode": 101}]}}
    settings.AT_USERNAME = "sandbox"
    seen = capture(monkeypatch, ok)
    sms.AfricasTalkingSms().send(to_e164="+256772000001", body="x")
    assert "api.sandbox.africastalking.com" in seen["req"].full_url
    settings.AT_USERNAME = "mc"
    seen = capture(monkeypatch, ok)
    sms.AfricasTalkingSms().send(to_e164="+256772000001", body="x")
    assert seen["req"].full_url.startswith("https://api.africastalking.com/")
    capture(monkeypatch, {"SMSMessageData": {"Recipients": [{"statusCode": 403}]}})
    with pytest.raises(ProviderError):
        sms.AfricasTalkingSms().send(to_e164="+256772000001", body="x")


def test_console_sms_prints_only_in_local_settings(settings, capsys):
    settings.SETTINGS_MODULE = "config.settings.local"
    sms.ConsoleSms().send(to_e164="+256772000001", body="Your Marriage Connect code is 123456.")
    assert "123456" in capsys.readouterr().err
    settings.SETTINGS_MODULE = "config.settings.prod"
    with pytest.raises(ProviderError):
        sms.ConsoleSms().send(to_e164="+256772000001", body="x")
    assert capsys.readouterr().err == ""


def test_sms_retriever_format_only_when_an_app_hash_is_configured(settings):
    settings.SMS_RETRIEVER_APP_HASH = ""
    assert sms.otp_message("123456").startswith("Your Marriage Connect code is 123456")
    settings.SMS_RETRIEVER_APP_HASH = "FA+9qCX9VSu"
    msg = sms.otp_message("123456")
    assert msg.startswith("<#> ") and msg.endswith("\nFA+9qCX9VSu") and len(msg.encode()) <= 140

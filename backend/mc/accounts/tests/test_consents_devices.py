import uuid

import pytest
from django.db import InternalError, transaction
from django.db.utils import IntegrityError

from mc.accounts import selectors, services
from mc.accounts.models import Account, ConsentRecord, Device
from mc.accounts.providers.sms import FakeSms
from mc.common import events
from mc.common.errors import ValidationFailed

from .helpers import PHONE, bearer, login

pytestmark = pytest.mark.django_db
J = {"content_type": "application/json"}
V = "2026-01"


def post_consents(api, resp, items):
    return api.post("/api/v1/me/consents", {"consents": items}, **bearer(resp), **J)


def test_consents_require_auth(api):
    assert api.post("/api/v1/me/consents", {"consents": []}, **J).status_code == 401


def test_record_consents_and_current_is_latest_row(api):
    r = login(api)
    post_consents(
        api,
        r,
        [
            {"kind": "terms", "version": V, "granted": True},
            {"kind": "marketing", "version": V, "granted": True},
        ],
    )
    resp = post_consents(api, r, [{"kind": "marketing", "version": V, "granted": False}])
    assert resp.status_code == 201
    assert resp.json()["consents"]["marketing"]["granted"] is False
    assert resp.json()["consents"]["terms"]["granted"] is True
    assert ConsentRecord.objects.filter(kind="marketing").count() == 2  # append-only history


def test_unknown_consent_kind_rejected(api):
    r = login(api)
    assert (
        post_consents(api, r, [{"kind": "zodiac", "version": V, "granted": True}]).status_code
        == 422
    )
    assert post_consents(api, r, []).status_code == 422


def test_consent_rows_cannot_be_updated_or_deleted():
    acct = Account.objects.create(phone_e164=PHONE)
    (rec,) = services.record_consent(
        account=acct, items=[{"kind": "terms", "version": V, "granted": True}], source="app"
    )
    with pytest.raises((InternalError, IntegrityError)), transaction.atomic():
        ConsentRecord.objects.filter(id=rec.id).update(granted=False)
    with pytest.raises((InternalError, IntegrityError)), transaction.atomic():
        ConsentRecord.objects.filter(id=rec.id).delete()


def test_verification_consents_gate():
    acct = Account.objects.create(phone_e164=PHONE)
    with pytest.raises(ValidationFailed) as ei:
        services.require_verification_consents(acct)
    assert set(ei.value.extra["missing_consents"]) == {"terms", "privacy", "data_transfer"}
    items = [
        {"kind": k, "version": V, "granted": True} for k in ("terms", "privacy", "data_transfer")
    ]
    services.record_consent(account=acct, items=items, source="app")
    services.require_verification_consents(acct)  # no raise
    services.record_consent(
        account=acct, items=[{"kind": "privacy", "version": V, "granted": False}], source="app"
    )
    with pytest.raises(ValidationFailed):
        services.require_verification_consents(acct)
    assert not selectors.has_required_verification_consents(acct)


def device(**kw):
    return {"install_id": str(uuid.uuid4()), "platform": "android", "push_token": "tok-1", **kw}


def test_register_device_upserts_and_stores_push_token(api):
    r = login(api, device=False)
    body = device()
    a = api.post("/api/v1/me/devices", body, **bearer(r), **J)
    b = api.post(
        "/api/v1/me/devices",
        {**body, "push_token": "tok-2", "app_version": "1.2.0"},
        **bearer(r),
        **J,
    )
    assert a.status_code == b.status_code == 200 and a.json()["id"] == b.json()["id"]
    d = Device.objects.get()
    assert d.push_token == "tok-2" and d.app_version == "1.2.0"


def test_push_token_moves_between_accounts_unique_per_platform(api):
    from django.test import Client

    r1 = login(api, device=False)
    r2 = login(Client(headers={"host": "api.mc.test"}), phone="+256772000055", device=False)
    api.post("/api/v1/me/devices", device(push_token="shared"), **bearer(r1), **J)
    Client(headers={"host": "api.mc.test"}).post(
        "/api/v1/me/devices", device(push_token="shared"), **bearer(r2), **J
    )
    assert Device.objects.filter(push_token="shared").count() == 1
    assert Device.objects.get(push_token="shared").account.phone_e164 == "+256772000055"


def test_new_device_on_existing_account_triggers_alert(api, django_capture_on_commit_callbacks):
    got = []
    from mc.accounts.events import NewDeviceSignIn

    events.subscribe(NewDeviceSignIn)(got.append)
    login(api, device={"install_id": str(uuid.uuid4()), "platform": "android"})
    assert FakeSms.outbox and len(FakeSms.outbox) == 1  # only the OTP: first device never alerts
    FakeSms.outbox.clear()
    with django_capture_on_commit_callbacks(execute=True):
        login(api, device={"install_id": str(uuid.uuid4()), "platform": "ios"})
    bodies = [b for _, b in FakeSms.outbox]
    assert any("new sign-in on an iPhone" in b for b in bodies)
    assert len(got) == 1


def test_same_device_signing_in_again_does_not_alert(api, django_capture_on_commit_callbacks):
    d = {"install_id": str(uuid.uuid4()), "platform": "android"}
    login(api, device=d)
    FakeSms.outbox.clear()
    with django_capture_on_commit_callbacks(execute=True):
        login(api, device=d)
    assert not any("new sign-in" in b for _, b in FakeSms.outbox)


def test_register_second_device_alerts_but_first_does_not(api, django_capture_on_commit_callbacks):
    r = login(api, device=False)
    FakeSms.outbox.clear()
    with django_capture_on_commit_callbacks(execute=True):
        api.post("/api/v1/me/devices", device(), **bearer(r), **J)
    assert FakeSms.outbox == []
    with django_capture_on_commit_callbacks(execute=True):
        api.post("/api/v1/me/devices", device(push_token="tok-9"), **bearer(r), **J)
    assert any("new sign-in" in b for _, b in FakeSms.outbox)


def test_register_device_validation(api):
    r = login(api, device=False)
    assert (
        api.post("/api/v1/me/devices", {"platform": "android"}, **bearer(r), **J).status_code == 422
    )
    bad = device(platform="windows")
    assert api.post("/api/v1/me/devices", bad, **bearer(r), **J).status_code == 422
    assert api.post("/api/v1/me/devices", device(), **J).status_code == 401


def test_hard_delete_is_the_only_way_to_remove_consents():
    acct = Account.objects.create(phone_e164=PHONE)
    services.record_consent(
        account=acct, items=[{"kind": "terms", "version": V, "granted": True}], source="app"
    )
    services.hard_delete_account(account=acct)
    assert not Account.objects.filter(id=acct.id).exists()
    assert not ConsentRecord.objects.exists()

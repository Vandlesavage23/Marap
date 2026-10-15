import uuid
from datetime import timedelta

import pytest
from django.core.management import call_command
from django.test import Client
from django.utils import timezone

from devtools.factories import create_member
from mc.accounts.models import Account
from mc.accounts.tests.helpers import bearer, last_code
from mc.audit.models import AuditEvent
from mc.beta import services
from mc.beta.models import BetaFeedback, DistrictCap, InviteCode
from mc.interests.tests.helpers import member
from mc.verification.tests.helpers import J

pytestmark = pytest.mark.django_db
PHONE = "+256772555001"


def signup(invite=None, phone=PHONE):
    c = Client(headers={"host": "api.mc.test"})
    c.post("/api/v1/auth/otp/start", {"phone": phone}, **J)
    body = {"phone": phone, "code": last_code(phone)}
    if invite is not None:
        body["invite_code"] = invite
    return c.post("/api/v1/auth/otp/verify", body, **J)


@pytest.fixture
def beta(settings):
    settings.BETA_INVITE_REQUIRED = True


def test_open_signup_when_beta_is_off():
    assert signup().status_code == 201


def test_invite_required_valid_code_works_once_and_is_consumed(beta):
    (code,) = services.create_invites(count=1)
    assert signup().status_code == 422  # no code
    assert not Account.objects.exists()
    assert signup(code.lower(), phone="+256772555002").status_code == 201  # case-insensitive
    assert InviteCode.objects.get().uses == 1
    assert signup(code, phone="+256772555003").status_code == 422  # exhausted
    assert Account.objects.count() == 1


def test_bad_code_does_not_burn_the_sms_code(beta):
    (code,) = services.create_invites(count=1)
    c = Client(headers={"host": "api.mc.test"})
    c.post("/api/v1/auth/otp/start", {"phone": PHONE}, **J)
    sms = last_code(PHONE)
    assert (
        c.post(
            "/api/v1/auth/otp/verify", {"phone": PHONE, "code": sms, "invite_code": "WRONG"}, **J
        ).status_code
        == 422
    )
    assert (
        c.post(
            "/api/v1/auth/otp/verify", {"phone": PHONE, "code": sms, "invite_code": code}, **J
        ).status_code
        == 201
    )


def test_existing_members_sign_in_without_an_invite(beta):
    who = member("male", trial=False)
    c = Client(headers={"host": "api.mc.test"})
    c.post("/api/v1/auth/otp/start", {"phone": who[2].phone_e164}, **J)
    r = c.post(
        "/api/v1/auth/otp/verify",
        {"phone": who[2].phone_e164, "code": last_code(who[2].phone_e164)},
        **J,
    )
    assert r.status_code == 200


def test_expired_inactive_and_multi_use_codes(beta):
    (a,) = services.create_invites(count=1, expires_at=timezone.now() - timedelta(days=1))
    (b,) = services.create_invites(count=1)
    InviteCode.objects.filter(code=b).update(active=False)
    (m,) = services.create_invites(count=1, max_uses=2)
    assert signup(a, "+256772555010").status_code == 422
    assert signup(b, "+256772555011").status_code == 422
    assert signup(m, "+256772555012").status_code == 201
    assert signup(m, "+256772555013").status_code == 201
    assert signup(m, "+256772555014").status_code == 422


def test_create_invites_command_and_audit():
    call_command("create_invites", "--count", "3", "--note", "wave 1")
    assert (
        InviteCode.objects.count() == 3
        and AuditEvent.objects.filter(action="beta.invites_created").exists()
    )
    assert all(len(c.code) == 8 for c in InviteCode.objects.all())


def test_feedback_is_encrypted_validated_and_erased_with_account(s3):
    from django.db import connection

    from mc.privacy import services as privacy_services

    who = member("female", trial=False)
    r = who[0].post(
        "/api/v1/beta/feedback",
        {"message": "The chat felt slow", "screen": "chat", "rating": 4},
        **bearer(who[1]),
        **J,
    )
    assert r.status_code == 201
    with connection.cursor() as cur:
        cur.execute("SELECT message FROM beta_betafeedback")
        assert cur.fetchone()[0].startswith("v1:")
    assert (
        who[0].post("/api/v1/beta/feedback", {"message": "x"}, **bearer(who[1]), **J).status_code
        == 422
    )
    assert (
        who[0]
        .post("/api/v1/beta/feedback", {"message": "fine", "rating": 9}, **bearer(who[1]), **J)
        .status_code
        == 422
    )
    assert (
        Client(headers={"host": "api.mc.test"})
        .post("/api/v1/beta/feedback", {"message": "hi there"}, **J)
        .status_code
        == 401
    )
    privacy_services._erase(who[2])
    assert not BetaFeedback.objects.exists()


def test_district_cap_throttles_go_live_per_day_and_pause_blocks():
    services.set_district_cap(district="Gulu", daily_cap=1, paused=False)
    a = create_member(district="Gulu", live=False)
    b = create_member(district="Gulu", live=False)
    o = create_member(district="Kampala", live=False)
    from mc.profiles import services as ps

    assert ps.go_live(account=a).status == "live"
    assert ps.go_live(account=a).status == "live"  # idempotent: no second claim
    from mc.common.errors import Conflict

    with pytest.raises(Conflict) as e:
        ps.go_live(account=b)
    assert e.value.code == "signups_paused"
    assert ps.go_live(account=o).status == "live"  # other districts unaffected
    DistrictCap.objects.update(count_date=timezone.localdate() - timedelta(days=1))
    assert ps.go_live(account=b).status == "live"  # next day the counter resets
    services.set_district_cap(district="Mbarara", daily_cap=None, paused=True)
    with pytest.raises(Conflict):
        ps.go_live(account=create_member(district="Mbarara", live=False))
    _ = uuid

import uuid

from django.test import Client

from devtools.factories import create_member
from mc.accounts.tests.helpers import bearer, login
from mc.entitlements import services as ent
from mc.profiles.models import Profile
from mc.verification.tests.helpers import J

_n = iter(range(10_000))


def member(gender="male", *, trial=True, age=30, **kw):
    """(client, login_response, account, profile_id) for a live verified member who can sign in."""
    phone = f"+2567722{next(_n):05d}"
    acct = create_member(phone=phone, gender=gender, age=age, **kw)
    c = Client(headers={"host": "api.mc.test"})
    r = login(c, phone=phone)
    assert r.status_code in (200, 201)
    if trial:
        ent.start_trial(account=acct)
    return c, r, acct, str(Profile.objects.get(account=acct).id)


def send(c, r, recipient_profile_id, key=None):
    return c.post(
        "/api/v1/interests",
        {"recipient_id": recipient_profile_id},
        **bearer(r),
        HTTP_IDEMPOTENCY_KEY=key or uuid.uuid4().hex,
        **J,
    )


def accept(c, r, interest_id, key=None):
    return c.post(
        f"/api/v1/interests/{interest_id}/accept",
        **bearer(r),
        HTTP_IDEMPOTENCY_KEY=key or uuid.uuid4().hex,
        **J,
    )


def pair():
    m = member("male", age=30)
    f = member("female", age=28)
    return m, f

"""The mobile contract fixture keeps working and carries the v2 states."""

import json
from io import StringIO

import pytest
from django.core.management import call_command
from django.test import Client

from mc.accounts.models import Account
from mc.entitlements import selectors

pytestmark = pytest.mark.django_db


def run_fixture():
    out = StringIO()
    call_command("contract_fixture", "--reset", stdout=out)
    return json.loads(out.getvalue().strip().splitlines()[-1])


def get(member, path):
    c = Client(headers={"host": "api.mc.test"})
    return c.get(path, HTTP_AUTHORIZATION=f"Bearer {member['access']}")


def test_fixture_builds_and_includes_v2_members():
    fx = run_fixture()
    members = fx["members"]
    assert {"ben", "newbie", "unverif", "quota", "qpeer1", "qpeer3"} <= set(members)

    unv = Account.objects.get(id=members["unverif"]["account_id"])
    assert unv.status == "pending_verification" and not selectors.entitlement_summary(unv).verified
    body = get(members["unverif"], "/api/v1/discovery").json()
    assert body["items"] and all(c["limited"] for c in body["items"])
    assert (
        get(members["unverif"], "/api/v1/me/profile")
        .json()["readiness"]["missing"]
        .count("verification")
        == 1
    )

    ent = get(members["quota"], "/api/v1/me/entitlements").json()
    assert (
        ent["state"] == "none" and ent["interests"]["used"] == 2 and ent["interests"]["limit"] == 3
    )

    newbie = get(members["newbie"], "/api/v1/me/entitlements").json()
    assert newbie["interests"]["used"] == 0 and newbie["trial"]["available"] is True
    assert get(members["newbie"], "/api/v1/discovery").status_code == 200

import pytest
from django.test import Client

from devtools.factories import create_member

pytestmark = pytest.mark.django_db


def get(**q):
    return Client(headers={"host": "api.mc.test"}).get("/api/v1/discovery/guest", q)


def test_guest_sees_limited_cards_of_the_gender_sought_without_signing_in():
    create_member(gender="female", name="Amani")
    create_member(gender="male", name="Brian")
    r = get(seeking="female")
    assert r.status_code == 200
    items = r.json()["items"]
    assert [i["display_name"] for i in items] == ["Amani"]
    assert items[0]["limited"] is True and len(items[0]["photos"]) <= 1
    assert "marriage_timeline" not in items[0] and "why" not in items[0]


def test_guest_feed_needs_a_valid_seeking_value_and_is_capped():
    assert get(seeking="x").status_code == 422
    for _ in range(3):
        create_member(gender="female")
    body = get(seeking="female", limit=2).json()
    assert len(body["items"]) == 2 and body["next_cursor"] == "2"
    last = get(seeking="female", cursor="2", limit=2).json()
    assert len(last["items"]) == 1 and last["sign_in_to_see_more"] is True
    assert get(seeking="female", cursor="999").json()["items"] == []

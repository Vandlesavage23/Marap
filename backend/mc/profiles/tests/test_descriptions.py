import uuid

import pytest
from django.test import Client

from mc.accounts.tests.helpers import bearer
from mc.profiles import selectors, services
from mc.profiles.models import Description, Profile
from mc.profiles.text_screen import APPROVE, REJECT, REVIEW, screen
from mc.verification.tests.helpers import J

from .helpers import verified_client

pytestmark = pytest.mark.django_db

GOOD = (
    "I am a primary school teacher in Wakiso who loves gardening, cooking matooke for my family on Sundays "
    "and long walks. I am looking for a kind, honest partner who values faith, family and hard work, and "
    "who is ready to build a home together."
)
assert 150 <= len(GOOD) <= 1000


# ---- screening corpus (English / Luganda / Swahili) -------------------------------------------
REJECTS = [
    # phone numbers incl. obfuscation
    ("call 0772 123 456 anytime", "phone_number"),
    ("reach +256-772-123-456", "phone_number"),
    ("07 7 2 1 2 3 4 5 6", "phone_number"),
    ("zero seven seven two one two three four five six", "phone_number"),
    ("zeero musanvu musanvu bbiri emu bbiri ssatu nnya ttaano mukaaga", "phone_number"),
    ("sifuri saba saba mbili moja mbili tatu nne tano sita", "phone_number"),
    ("07o2.123.456", "phone_number"),
    # URLs / email / apps
    ("see me at www.myprofile.com", "url"),
    ("find me on https://x.co/abc", "url"),
    ("my site is lovelife.ug", "url"),
    ("mail amani.k@gmail.com", "email"),
    ("write to amani at gmail dot com", "email"),
    ("add me on whatsapp", "messaging_app"),
    ("my WhatsApp is ready", "messaging_app"),
    ("telegram me", "messaging_app"),
    ("dm me on insta", "messaging_app"),
    # contact phrases: English / Luganda / Swahili
    ("please call me tonight", "contact_details"),
    ("text me when you can", "contact_details"),
    ("my number is available later", "contact_details"),
    ("nkubira ku ssimu", "contact_details"),
    ("mpandikira bw'oba oyagala", "contact_details"),
    ("nnamba yange ngikuwa", "contact_details"),
    ("ntumire ku nnamba yo", "contact_details"),
    ("nipigie ukipenda", "contact_details"),
    ("nitumie ujumbe leo", "contact_details"),
    ("namba yangu ni siri", "contact_details"),
    # money
    ("send me money for fees", "money_request"),
    ("please tuma pesa kidogo", "money_request"),
    ("ntumire ssente ntandike", "money_request"),
    ("nitumie pesa kwa mpesa", "money_request"),
    ("naomba pesa ya kodi", "money_request"),
    ("invest with me in forex", "money_request"),
    ("western union only", "money_request"),
    ("bitcoin lover", "money_request"),
    ("sugar daddy wanted", "sexual_content"),
]
REVIEWS = [("what the fuck is wrong with people", "profanity")]
APPROVES = [
    GOOD,
    "I was born in 1995 and I have two children aged 7 and 4. I work at a bank in Kampala and attend church.",
    "I enjoy football, reading and cooking. I'm 5 foot 11 and I live in Entebbe with my mother.",
    "Nsiimye okufumba n'okusoma. Ndi musomesa ku ssomero e Wakiso, njagala omuntu omwesimbu.",
    "Napenda kusoma na kupika. Mimi ni mwalimu Kampala, natafuta mwenzi mwaminifu mwenye hofu ya Mungu.",
    "My favourite number is seven and I love the year two thousand and twenty.",
]


@pytest.mark.parametrize(("text", "reason"), REJECTS)
def test_screen_rejects(text, reason):
    v = screen(text)
    assert (v.outcome, v.reason) == (REJECT, reason)


@pytest.mark.parametrize(("text", "reason"), REVIEWS)
def test_screen_sends_borderline_to_review(text, reason):
    v = screen(text)
    assert (v.outcome, v.reason) == (REVIEW, reason)


@pytest.mark.parametrize("text", APPROVES)
def test_screen_approves_clean_text(text):
    assert screen(text).outcome == APPROVE


# ---- service/API -------------------------------------------------------------------------------
def post_desc(c, r, text, key=None):
    return c.post(
        "/api/v1/me/descriptions",
        {"text": text},
        **bearer(r),
        HTTP_IDEMPOTENCY_KEY=key or uuid.uuid4().hex,
        **J,
    )


def test_requires_verified_account_and_auth():
    from mc.verification.tests.helpers import new_user

    c, r = new_user()
    assert post_desc(c, r, GOOD).status_code == 403
    assert (
        Client(headers={"host": "api.mc.test"}).post("/api/v1/me/descriptions", {}, **J).status_code
        == 401
    )


def test_clean_description_is_approved_and_becomes_current():
    c, r, acct = verified_client()
    resp = post_desc(c, r, GOOD)
    assert (
        resp.status_code == 201
        and resp.json()["status"] == "approved"
        and resp.json()["version"] == 1
    )
    p = Profile.objects.get()
    assert p.current_description.text == GOOD
    assert selectors.has_approved_description(acct.id)


@pytest.mark.parametrize("bad", ["x" * 149, "x" * 1001])
def test_length_limits(bad):
    c, r, _ = verified_client()
    resp = post_desc(c, r, bad)
    assert resp.status_code == 422 and resp.json()["code"] == "validation_error"
    assert Description.objects.count() == 0


def test_rejected_description_is_422_with_reason_and_not_current():
    c, r, acct = verified_client()
    post_desc(c, r, GOOD)
    resp = post_desc(c, r, GOOD + " Call me on 0772 123 456.")
    assert resp.status_code == 422
    body = resp.json()
    assert body["code"] == "description_rejected" and body["reason"] == "phone_number"
    p = Profile.objects.get()
    assert p.current_description.version == 1  # the good one stays current
    assert Description.objects.get(version=2).status == "rejected"


def test_new_version_replaces_current_and_versions_increment():
    c, r, _ = verified_client()
    post_desc(c, r, GOOD)
    post_desc(c, r, GOOD + " I also love music.")
    assert Profile.objects.get().current_description.version == 2
    items = c.get("/api/v1/me/descriptions", **bearer(r)).json()
    assert [i["version"] for i in items["items"]] == [2, 1] and items["current_version"] == 2


def test_description_text_is_immutable():
    c, r, _ = verified_client()
    post_desc(c, r, GOOD)
    d = Description.objects.get()
    d.text = "changed"
    with pytest.raises(ValueError):
        d.save()
    d = Description.objects.get()
    d.reviewed_by = uuid.uuid4()
    d.save()  # non-text fields (review metadata) may change


def test_borderline_goes_pending_then_review_decides():
    c, r, acct = verified_client()
    pending = post_desc(
        c, r, GOOD + " Some people are such bullshit and I have no patience for them."
    )
    assert pending.status_code == 201 and pending.json()["status"] == "pending"
    p = Profile.objects.get()
    assert p.current_description is None and not selectors.has_approved_description(acct.id)
    desc = Description.objects.get()
    services.review_description(description_id=desc.id, approve=True, reviewer_id=uuid.uuid4())
    assert Profile.objects.get().current_description_id == desc.id
    with pytest.raises(Exception):  # noqa: B017 - already decided → Conflict
        services.review_description(description_id=desc.id, approve=False, reviewer_id=uuid.uuid4())


def test_new_submission_supersedes_older_pending():
    c, r, _ = verified_client()
    post_desc(c, r, GOOD + " Some people are such bullshit and I have no patience.")
    post_desc(c, r, GOOD)
    statuses = list(Description.objects.order_by("version").values_list("status", "reject_reason"))
    assert statuses == [("rejected", "superseded"), ("approved", "")]


def test_idempotent_retry_creates_one_version():
    c, r, _ = verified_client()
    a = post_desc(c, r, GOOD, key="desc-key-12345")
    b = post_desc(c, r, GOOD, key="desc-key-12345")
    assert a.json() == b.json() and Description.objects.count() == 1


def test_unicode_is_normalised():
    c, r, _ = verified_client()
    fancy = GOOD.replace("teacher", "ｔｅａｃｈｅｒ")  # full-width letters
    post_desc(c, r, fancy)
    assert "teacher" in Description.objects.get().text

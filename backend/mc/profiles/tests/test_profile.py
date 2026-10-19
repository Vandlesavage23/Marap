import importlib
import inspect
import pkgutil

import pytest
from django.db import connection
from django.test import Client

from mc.accounts.tests.helpers import bearer
from mc.profiles.models import Profile
from mc.verification.tests.helpers import new_user

from .helpers import BASIC, consent, patch, verified_client

pytestmark = pytest.mark.django_db


def test_unverified_user_has_no_profile_until_about_you():
    """v2: before the identity check a member creates a draft ("About you") by declaring a birth date; without
    it nothing is created. Everything else about profile building still needs verification."""
    c, r = new_user()
    resp = c.get("/api/v1/me/profile", **bearer(r))
    assert resp.status_code == 403 and resp.json()["code"] == "not_verified"
    resp = patch(c, r, **BASIC)  # no birth date → nothing to create the draft from
    assert resp.status_code == 422 and resp.json()["missing"] == ["birth_date"]
    assert Profile.objects.count() == 0
    assert Client(headers={"host": "api.mc.test"}).get("/api/v1/me/profile").status_code == 401


def test_profile_created_from_verification_with_age_not_birth_date():
    c, r, _ = verified_client()
    body = c.get("/api/v1/me/profile", **bearer(r)).json()
    assert body["status"] == "draft" and body["age"] >= 18
    assert "birth_date" not in body and "date_of_birth" not in body
    assert Profile.objects.get().birth_date.year == 1995


def test_patch_valid_and_completeness():
    c, r, _ = verified_client()
    resp = patch(c, r, **BASIC)
    assert resp.status_code == 200
    body = resp.json()
    assert body["display_name"] == "Amani" and body["completeness"] == 21
    body = patch(
        c,
        r,
        languages=["EN", "lg"],
        occupation="Teacher",
        education="bachelors",
        has_children="no",
        wants_children="yes",
        marriage_form_preference="monogamous_only",
    ).json()
    assert body["languages"] == ["en", "lg"] and body["completeness"] == 30


def test_birth_date_and_unknown_fields_are_not_editable():
    c, r, _ = verified_client()
    c.get("/api/v1/me/profile", **bearer(r))
    assert patch(c, r, birth_date="1990-01-01").status_code in (422,)
    assert Profile.objects.get().birth_date.year == 1995
    assert patch(c, r, status="live").status_code == 422
    assert patch(c, r, completeness=100).status_code == 422


@pytest.mark.parametrize(
    "name",
    [
        "A",
        "x" * 31,
        "Amani123",
        "Am@ni",
        "<b>x</b>",
        "Admin Support",
        "Marriage Connect Team",
        "f.u.c.k",
    ],
)
def test_display_name_rejected(name):
    c, r, _ = verified_client()
    assert patch(c, r, display_name=name).status_code == 422


@pytest.mark.parametrize(
    "name", ["Amani", "Jean-Luc", "O'Brien", "Nakato Mary", "Ｂｕｓｉｎｇｙｅ"]
)
def test_display_name_accepted_and_normalised(name):
    c, r, _ = verified_client()
    resp = patch(c, r, display_name=name)
    assert resp.status_code == 200
    assert resp.json()["display_name"] == (name if name != "Ｂｕｓｉｎｇｙｅ" else "Busingye")


def test_invalid_enum_district_language_rejected_and_atomic():
    c, r, _ = verified_client()
    assert patch(c, r, gender="other").status_code == 422
    assert patch(c, r, district="Atlantis").status_code == 422
    assert patch(c, r, languages=["english"]).status_code == 422
    resp = patch(c, r, display_name="Valid", district="Atlantis")  # one bad field → nothing saved
    assert resp.status_code == 422 and Profile.objects.get().display_name == ""


def test_gender_immutable_after_set():
    c, r, _ = verified_client()
    patch(c, r, gender="female")
    assert patch(c, r, gender="male").status_code == 409
    assert patch(c, r, gender="female").status_code == 200


def test_location_rounded_to_roughly_1km():
    c, r, _ = verified_client()
    body = patch(c, r, location={"lat": 0.347596, "lng": 32.582520}).json()
    assert body["location"] == {"lat": 0.35, "lng": 32.58}
    assert patch(c, r, location=None).json()["location"] is None
    assert patch(c, r, location={"lat": 123, "lng": 0}).status_code == 422


def test_diaspora_country():
    c, r, _ = verified_client()
    body = patch(c, r, district="abroad", diaspora_country="gb").json()
    assert body["diaspora_country"] == "GB"
    assert patch(c, r, district="Kampala").json()["diaspora_country"] == ""
    assert patch(c, r, district="abroad", diaspora_country="GBR").status_code == 422


# ---- special data: consent gated, encrypted, withdrawable -------------------------------------
def test_religion_requires_consent():
    c, r, _ = verified_client()
    resp = patch(c, r, religion="Catholic")
    assert resp.status_code == 422 and resp.json()["missing_consent"] == "special_religion"
    assert Profile.objects.get().religion is None


def test_religion_encrypted_at_rest_and_withdrawal_deletes(django_capture_on_commit_callbacks):
    c, r, _ = verified_client()
    consent(c, r, "special_religion")
    assert (
        patch(c, r, religion="Catholic", religion_practice="weekly").json()["religion"]
        == "Catholic"
    )
    with connection.cursor() as cur:
        cur.execute("SELECT religion, religion_practice FROM profiles_profile")
        raw = cur.fetchone()
    assert all(v.startswith("v1:") and "Catholic" not in v for v in raw)
    with django_capture_on_commit_callbacks(execute=True):
        consent(c, r, "special_religion", granted=False)
    p = Profile.objects.get()
    assert p.religion is None and p.religion_practice is None
    assert patch(c, r, religion="x").status_code == 422


# ---- married rule BR-MAR-01 --------------------------------------------------------------------
def male_ready(c, r):
    consent(c, r, "married_visibility")
    return patch(
        c,
        r,
        **{
            **BASIC,
            "gender": "male",
            "marital_status": "married_customary",
            "married_declaration": True,
        },
    )


def test_married_allowed_for_ugandan_man_with_declaration_and_consent():
    c, r, _ = verified_client()
    resp = male_ready(c, r)
    assert resp.status_code == 200 and resp.json()["married_declaration"] is True


@pytest.mark.parametrize("variant", ["woman", "no_declaration", "no_consent", "abroad", "flag_off"])
def test_married_rejected_otherwise(variant, settings):
    c, r, _ = verified_client()
    if variant != "no_consent":
        consent(c, r, "married_visibility")
    body = {
        **BASIC,
        "gender": "male",
        "marital_status": "married_islamic",
        "married_declaration": True,
    }
    if variant == "woman":
        body["gender"] = "female"
    if variant == "no_declaration":
        body["married_declaration"] = False
    if variant == "abroad":
        body.update(district="abroad", diaspora_country="GB")
    if variant == "flag_off":
        settings.MARRIED_PROFILES_ENABLED = False
    resp = patch(c, r, **body)
    assert resp.status_code == 422 and resp.json()["code"] == "married_not_eligible"
    assert Profile.objects.get().marital_status == ""


def test_declaration_cleared_when_status_changes_away_from_married():
    c, r, _ = verified_client()
    male_ready(c, r)
    body = patch(c, r, marital_status="divorced").json()
    assert body["married_declaration"] is False


def test_opting_in_to_married_profiles_needs_consent_and_withdrawal_resets(
    django_capture_on_commit_callbacks,
):
    c, r, _ = verified_client()
    assert patch(c, r, show_married_profiles=True).status_code == 422
    consent(c, r, "married_visibility")
    assert patch(c, r, show_married_profiles=True).json()["show_married_profiles"] is True
    with django_capture_on_commit_callbacks(execute=True):
        consent(c, r, "married_visibility", granted=False)
    assert Profile.objects.get().show_married_profiles is False
    assert patch(c, r, show_married_profiles=False).status_code == 200


def test_married_visibility_default_false_and_configurable(settings):
    c, r, _ = verified_client()
    assert c.get("/api/v1/me/profile", **bearer(r)).json()["show_married_profiles"] is False


# ---- public view + privacy allowlist ----------------------------------------------------------
def make_live(profile_id_owner_phone, **kw):
    Profile.objects.filter(account__phone_e164=profile_id_owner_phone).update(status="live", **kw)


def test_public_profile_visibility_rules():
    from mc.entitlements import services as ent

    cf, rf, af = verified_client("+256772000001")  # woman
    cm, rm, am = verified_client("+256772000002")  # man
    patch(cf, rf, **BASIC)
    patch(cm, rm, **{**BASIC, "gender": "male", "display_name": "Okello"})
    pf, pm = Profile.objects.get(account=af), Profile.objects.get(account=am)
    ent.start_trial(account=am)
    # target not live → 404; live → visible to an opposite-gender viewer with browse
    assert cm.get(f"/api/v1/profiles/{pf.id}", **bearer(rm)).status_code == 404
    Profile.objects.filter(id=pf.id).update(status="live")
    resp = cm.get(f"/api/v1/profiles/{pf.id}", **bearer(rm))
    assert resp.status_code == 200 and resp.json()["display_name"] == "Amani"
    # no browse capability → 404 (not 403: no existence oracle)
    assert cf.get(f"/api/v1/profiles/{pm.id}", **bearer(rf)).status_code == 404
    Profile.objects.filter(id=pm.id).update(status="live")
    ent.start_trial(account=af)
    assert cf.get(f"/api/v1/profiles/{pm.id}", **bearer(rf)).status_code == 200
    # same-gender viewer cannot see
    cx, rx, ax = verified_client("+256772000003")
    patch(cx, rx, **{**BASIC, "display_name": "Zawadi"})
    ent.start_trial(account=ax)
    assert cx.get(f"/api/v1/profiles/{pf.id}", **bearer(rx)).status_code == 404
    # self can always see; unauthenticated cannot; suspended account hidden
    assert cf.get(f"/api/v1/profiles/{pf.id}", **bearer(rf)).status_code == 200
    assert (
        Client(headers={"host": "api.mc.test"}).get(f"/api/v1/profiles/{pf.id}").status_code == 401
    )
    am.status = "suspended"
    am.save()


def test_public_payload_is_an_allowlist():
    from mc.entitlements import services as ent

    cf, rf, af = verified_client("+256772000001")
    cm, rm, am = verified_client("+256772000002")
    consent(cf, rf, "special_religion")
    patch(cf, rf, **BASIC, religion="Anglican", occupation="Nurse")
    patch(cm, rm, **{**BASIC, "gender": "male", "display_name": "Okello"})
    Profile.objects.filter(account=af).update(status="live")
    ent.start_trial(account=am)
    pid = Profile.objects.get(account=af).id
    text = cm.get(f"/api/v1/profiles/{pid}", **bearer(rm)).content.decode()
    for banned in (
        "Anglican",
        "religion",
        "1995",
        "birth",
        "phone",
        "+2567",
        "id_number",
        "location",
    ):
        assert banned not in text
    assert "Nurse" in text


def test_serializers_never_expose_identity_fields():
    """AC MC-045: legal-identity fields are in no serializer, anywhere in the project."""
    banned = (
        "legal_name",
        "full_name",
        "id_number",
        "id_hmac",
        "identity_hmac",
        "date_of_birth",
        "birth_date",
        "passport",
        "national_id",
    )
    import mc

    checked = 0
    for mod in pkgutil.walk_packages(mc.__path__, "mc."):
        if ".tests" in mod.name or not mod.name.endswith((".serializers",)):
            continue
        module = importlib.import_module(mod.name)
        for name, cls in inspect.getmembers(module, inspect.isclass):
            if hasattr(cls, "_declared_fields"):
                checked += 1
                for field in cls._declared_fields:
                    assert not any(b in field for b in banned), f"{mod.name}.{name}.{field}"
        source = inspect.getsource(module)
        # the profile serializers build dicts: scan their keys too
        if "profiles" in mod.name:
            for b in ("legal_name", "id_number", "id_hmac", "date_of_birth"):
                assert f'"{b}"' not in source
    assert checked >= 5

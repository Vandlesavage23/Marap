"""Explicit allowlists only (CLAUDE.md rule 3). Nothing here may expose legal name, ID numbers,
ID hashes, phone, email or birth date; `test_serializers_never_expose_identity_fields` enforces it."""

from rest_framework import serializers

from mc.profiles import selectors
from mc.profiles.models import Profile

MARITAL_LABELS = {
    "never_married": "Never married",
    "divorced": "Divorced",
    "widowed": "Widowed",
    "married_customary": "Married (customary)",
    "married_islamic": "Married (Islamic)",
}


class LocationSerializer(serializers.Serializer):
    lat = serializers.FloatField(min_value=-90, max_value=90)
    lng = serializers.FloatField(min_value=-180, max_value=180)


class ProfileUpdateSerializer(serializers.Serializer):
    display_name = serializers.CharField(max_length=60, required=False)
    gender = serializers.CharField(max_length=10, required=False)
    district = serializers.CharField(max_length=40, required=False)
    diaspora_country = serializers.CharField(max_length=2, required=False, allow_blank=True)
    location = LocationSerializer(required=False, allow_null=True)
    intention = serializers.CharField(max_length=24, required=False, allow_blank=True)
    marriage_timeline = serializers.CharField(max_length=10, required=False, allow_blank=True)
    marital_status = serializers.CharField(max_length=20, required=False, allow_blank=True)
    married_declaration = serializers.BooleanField(required=False)
    marriage_form_preference = serializers.CharField(
        max_length=30, required=False, allow_blank=True
    )
    show_married_profiles = serializers.BooleanField(required=False)
    has_children = serializers.CharField(max_length=24, required=False, allow_blank=True)
    wants_children = serializers.CharField(max_length=8, required=False, allow_blank=True)
    languages = serializers.ListField(
        child=serializers.CharField(max_length=3), required=False, max_length=8
    )
    religion = serializers.CharField(
        max_length=60, required=False, allow_blank=True, allow_null=True
    )
    religion_practice = serializers.CharField(
        max_length=60, required=False, allow_blank=True, allow_null=True
    )
    occupation = serializers.CharField(max_length=60, required=False, allow_blank=True)
    education = serializers.CharField(max_length=24, required=False, allow_blank=True)


def own_profile(profile: Profile) -> dict[str, object]:
    return {
        "id": str(profile.id),
        "status": profile.status,
        "completeness": profile.completeness,
        "age": selectors.age_of(profile),
        "display_name": profile.display_name,
        "gender": profile.gender,
        "district": profile.district,
        "diaspora_country": profile.diaspora_country,
        "location": (
            {"lat": float(profile.location_lat), "lng": float(profile.location_lng)}
            if profile.location_lat is not None and profile.location_lng is not None
            else None
        ),
        "intention": profile.intention,
        "marriage_timeline": profile.marriage_timeline,
        "marital_status": profile.marital_status,
        "married_declaration": profile.married_declaration_at is not None,
        "marriage_form_preference": profile.marriage_form_preference,
        "show_married_profiles": profile.show_married_profiles,
        "has_children": profile.has_children,
        "wants_children": profile.wants_children,
        "languages": profile.languages,
        "religion": profile.religion,
        "religion_practice": profile.religion_practice,
        "occupation": profile.occupation,
        "education": profile.education,
    }


def public_profile(profile: Profile) -> dict[str, object]:
    """What other members may see. No religion text, no birth date (age only), no location point."""
    return {
        "profile_id": str(profile.id),
        "display_name": profile.display_name,
        "age": selectors.age_of(profile),
        "district": profile.district,
        "intention": profile.intention,
        "marriage_timeline": profile.marriage_timeline,
        "marital_status_label": (
            MARITAL_LABELS[profile.marital_status]
            if profile.marital_status.startswith("married")
            else None
        ),
        "marriage_form_preference": profile.marriage_form_preference,
        "has_children": profile.has_children,
        "wants_children": profile.wants_children,
        "languages": profile.languages,
        "occupation": profile.occupation,
        "education": profile.education,
        "badges": ["age_verified", "identity_verified"],
    }

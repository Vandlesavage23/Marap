import phonenumbers

from mc.common.errors import ValidationFailed


def normalise(raw: str, *, default_region: str = "UG") -> str:
    """E.164 (Uganda default +256). Raises ValidationFailed for unparseable/invalid numbers."""
    try:
        parsed = phonenumbers.parse(raw, default_region)
    except phonenumbers.NumberParseException as exc:
        raise ValidationFailed("Enter a valid phone number.") from exc
    if not phonenumbers.is_valid_number(parsed):
        raise ValidationFailed("Enter a valid phone number.")
    return phonenumbers.format_number(parsed, phonenumbers.PhoneNumberFormat.E164)


def calling_code(e164: str) -> str:
    return str(phonenumbers.parse(e164).country_code)

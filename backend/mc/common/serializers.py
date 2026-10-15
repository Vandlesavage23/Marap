from typing import Any

from rest_framework import serializers

from .errors import ValidationFailed


def reject_unknown_fields(serializer: serializers.Serializer, data: Any) -> None:
    """DRF silently drops unknown keys; for write endpoints we refuse them so a client typo (or an attempt
    to set `status`, `birth_date`, ...) fails loudly instead of being ignored."""
    if isinstance(data, dict):
        unknown = sorted(set(data) - set(serializer.fields))
        if unknown:
            raise ValidationFailed(f"Unknown fields: {', '.join(unknown)}", unknown_fields=unknown)

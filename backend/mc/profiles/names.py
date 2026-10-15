"""Display-name rules: NFKC normalisation, letters/spaces only, profanity + impersonation screen."""

import re
import unicodedata

from mc.common.errors import ValidationFailed

_ALLOWED = re.compile(r"^[^\W\d_]+(?:[ '\-][^\W\d_]+)*$", re.UNICODE)
# Seed lists; the safety module owns the maintained, versioned lists (MC-079). English/Luganda/Swahili.
_PROFANITY = frozenset({"fuck", "shit", "bitch", "pussy", "dick", "malaya", "kuma"})
_IMPERSONATION = (
    "admin",
    "support",
    "moderator",
    "marriageconnect",
    "marriage connect",
    "official",
    "staff",
)


def normalise_display_name(raw: str) -> str:
    name = " ".join(unicodedata.normalize("NFKC", raw).split())
    if not 2 <= len(name) <= 30:
        raise ValidationFailed("Display name must be 2–30 characters.")
    if not _ALLOWED.match(name):
        raise ValidationFailed("Use letters only (spaces, hyphens and apostrophes are fine).")
    folded = name.casefold()
    squashed = re.sub(r"[^a-z]", "", folded)
    if any(w in squashed for w in _PROFANITY):
        raise ValidationFailed("Please choose a different display name.")
    if any(w.replace(" ", "") in squashed for w in _IMPERSONATION):
        raise ValidationFailed("That name isn't available.")
    return name

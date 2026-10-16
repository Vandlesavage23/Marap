"""Which flag keys exist and how they may be used. Pure data and pattern checks: no I/O."""

import re

from django.conf import settings

# Phase 5 features (CLAUDE.md rule 12): the stubs exist, nothing is built. These can't be switched on at
# runtime until a backlog epic (approved after counsel's review) removes the lock here.
LOCKED_OFF = frozenset({"phase5_disclosure", "phase5_counselling", "phase5_due_diligence"})

# Non-sensitive flags the app may read before sign-in (GET /config/flags).
PUBLIC_FLAGS = ("voice_notes", "data_saver_default_on_cellular")

# `ranking_model_vN` selects the discovery ranking model version.
_RANKING_KEY = re.compile(r"^ranking_model_v[1-9][0-9]{0,2}$")

DESCRIPTIONS = {
    "phase5_disclosure": "Genotype/medical disclosure (Phase 5; locked off).",
    "phase5_counselling": "Counselling marketplace (Phase 5; locked off).",
    "phase5_due_diligence": "Legal due diligence (Phase 5; locked off).",
    "voice_notes": "Members can send voice notes in chat.",
    "data_saver_default_on_cellular": "The app starts in data-saver mode on mobile data.",
}


def defaults() -> dict[str, bool]:
    return {k: bool(v) for k, v in settings.FEATURE_FLAGS_DEFAULT.items()}


def is_known(key: str) -> bool:
    return key in settings.FEATURE_FLAGS_DEFAULT or bool(_RANKING_KEY.match(key))


def default_for(key: str) -> bool:
    return bool(settings.FEATURE_FLAGS_DEFAULT.get(key, False))


def description_for(key: str) -> str:
    if _RANKING_KEY.match(key):
        return f"Use discovery ranking model {key.rsplit('_', 1)[1]}."
    return DESCRIPTIONS.get(key, "")

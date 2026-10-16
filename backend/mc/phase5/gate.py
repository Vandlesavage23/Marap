"""The single flag check every Phase 5 stub uses, and the error it raises when a feature is off."""

from mc.common.errors import NotFound
from mc.flags import selectors as flag_selectors

DISCLOSURE = "phase5_disclosure"
COUNSELLING = "phase5_counselling"
DUE_DILIGENCE = "phase5_due_diligence"
ALL_FLAGS = (DISCLOSURE, COUNSELLING, DUE_DILIGENCE)


class NotEnabled(NotFound):
    """The feature is switched off. It looks like any unknown resource (404, no hint that it exists)."""


def is_enabled(flag: str) -> bool:
    return flag_selectors.flag_enabled(flag)


def require_enabled(flag: str) -> None:
    if not is_enabled(flag):
        raise NotEnabled()

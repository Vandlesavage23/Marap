from typing import TYPE_CHECKING

from . import selectors

if TYPE_CHECKING:
    from mc.accounts.models import Account


def match_photo_policy(viewer: "Account", media) -> bool:  # type: ignore[no-untyped-def]
    """Matched members may see each other's approved photos (even when browsing has lapsed)."""
    from mc.profiles.selectors import is_approved_photo_media

    return (
        is_approved_photo_media(media)
        and selectors.active_match_between(viewer.id, media.owner_id) is not None
    )

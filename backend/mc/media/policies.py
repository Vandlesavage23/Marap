"""Who may read a media object. Default deny; modules register a viewer policy per purpose at app
ready time (profiles → profile_photo, messaging → chat_image/voice_note) so `media` never imports them."""

from collections.abc import Callable
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from mc.accounts.models import Account

    from .models import MediaObject

ViewerPolicy = Callable[["Account", "MediaObject"], bool]
_policies: dict[str, list[ViewerPolicy]] = {}


def register_viewer_policy(purpose: str, policy: ViewerPolicy) -> None:
    """Add a grant for `purpose`; a viewer may see the media if ANY registered policy allows it."""
    if policy not in _policies.setdefault(purpose, []):
        _policies[purpose].append(policy)


def unregister_viewer_policy(purpose: str, policy: ViewerPolicy) -> None:  # tests
    if policy in _policies.get(purpose, []):
        _policies[purpose].remove(policy)


def can_view_media(viewer: "Account", media: "MediaObject") -> bool:
    if media.status != "ready":
        return (
            media.owner_id == viewer.id
        )  # owner may see their own status/preview while it's pending
    if media.owner_id == viewer.id:
        return True
    return any(policy(viewer, media) for policy in _policies.get(media.purpose, []))

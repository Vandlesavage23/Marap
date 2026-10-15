"""Who may read a media object. Default deny; modules register a viewer policy per purpose at app
ready time (profiles → profile_photo, messaging → chat_image/voice_note) so `media` never imports them."""

from collections.abc import Callable
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from mc.accounts.models import Account

    from .models import MediaObject

ViewerPolicy = Callable[["Account", "MediaObject"], bool]
_policies: dict[str, ViewerPolicy] = {}


def register_viewer_policy(purpose: str, policy: ViewerPolicy) -> None:
    _policies[purpose] = policy


def can_view_media(viewer: "Account", media: "MediaObject") -> bool:
    if media.status != "ready":
        return (
            media.owner_id == viewer.id
        )  # owner may see their own status/preview while it's pending
    if media.owner_id == viewer.id:
        return True
    policy = _policies.get(media.purpose)
    return bool(policy and policy(viewer, media))

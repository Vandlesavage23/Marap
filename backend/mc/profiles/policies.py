from typing import TYPE_CHECKING

from mc.entitlements import selectors as entitlement_selectors
from mc.safety import selectors as safety_selectors

from .models import Profile

if TYPE_CHECKING:
    from mc.accounts.models import Account


def is_visible_profile(target: Profile) -> bool:
    return target.status == Profile.Status.LIVE and target.account.status == "active"


def can_view_profile(viewer: "Account", target: Profile) -> bool:
    """Self always. Others: target live+active, opposite gender, viewer verified with `browse`
    capability. Blocks and relationship-based access (pending interest / match) are added by the
    safety (MC-085) and interests (MC-065) tickets."""
    if target.account_id == viewer.id:
        return True
    if not is_visible_profile(target):
        return False
    if safety_selectors.is_blocked_either_way(viewer.id, target.account_id):
        return False
    viewer_profile = Profile.objects.filter(account=viewer).only("gender").first()
    if (
        viewer_profile is None
        or not viewer_profile.gender
        or viewer_profile.gender == target.gender
    ):
        return False
    return entitlement_selectors.has_capability(viewer, "browse")


def photo_media_viewer_policy(viewer: "Account", media) -> bool:  # type: ignore[no-untyped-def]
    """Media policy for `profile_photo`: approved photos of profiles the viewer may see."""
    from .models import Photo

    photo = Photo.objects.select_related("profile__account").filter(media=media).first()
    return bool(
        photo
        and photo.moderation_status == Photo.Moderation.APPROVED
        and can_view_profile(viewer, photo.profile)
    )


class BatchedProfileAccess:
    """`can_view_profile(viewer, target)` for MANY targets with the viewer-side facts (blocks, own gender,
    `browse` capability) read once, lazily, instead of once per target. Same rules as `can_view_profile`;
    callers must already know each target is a live, active profile (`is_visible_profile`)."""

    def __init__(self, viewer: "Account") -> None:
        self._viewer = viewer
        self._blocked: set | None = None
        self._gender: str | None = None
        self._browse: bool | None = None

    def can_view(self, target: Profile) -> bool:
        viewer = self._viewer
        if target.account_id == viewer.id:
            return True
        if self._blocked is None:
            self._blocked = safety_selectors.blocked_either_way_ids(viewer.id)
        if target.account_id in self._blocked:
            return False
        if self._gender is None:
            self._gender = (
                Profile.objects.filter(account=viewer).values_list("gender", flat=True).first()
                or ""
            )
        if not self._gender or self._gender == target.gender:
            return False
        if self._browse is None:
            self._browse = entitlement_selectors.has_capability(viewer, "browse")
        return self._browse

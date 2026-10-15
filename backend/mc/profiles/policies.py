from typing import TYPE_CHECKING

from mc.entitlements import selectors as entitlement_selectors

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

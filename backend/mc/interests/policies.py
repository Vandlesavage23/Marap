from typing import TYPE_CHECKING

from django.db.models import Q

from .models import Interest

if TYPE_CHECKING:
    from mc.accounts.models import Account


def interest_photo_policy(viewer: "Account", media) -> bool:  # type: ignore[no-untyped-def]
    """Media grant: a member may see the photos of someone with whom they have a *pending or accepted*
    interest (either direction). Photo approval and ownership are re-checked by the media pipeline."""
    from mc.profiles.selectors import is_approved_photo_media

    owner_id = media.owner_id
    if not is_approved_photo_media(media):
        return False
    return Interest.objects.filter(
        Q(sender_id=owner_id, recipient_id=viewer.id)
        | Q(sender_id=viewer.id, recipient_id=owner_id),
        status__in=[Interest.Status.PENDING, Interest.Status.ACCEPTED],
    ).exists()

"""Who may call an endpoint once authenticated.

* `IsActiveMember` (the default for member features): authenticated and NOT suspended. A suspended member can
  still sign in (to see why and appeal) but every feature endpoint refuses them.
* `IsAuthenticatedAnyStatus`: account controls only — /me, sessions, consents, appeals, deletion, export.
"""

from rest_framework.permissions import BasePermission

from mc.common.errors import Forbidden

from . import constants


class IsAuthenticatedAnyStatus(BasePermission):
    def has_permission(self, request, view) -> bool:  # type: ignore[no-untyped-def]
        return bool(request.user and request.user.is_authenticated)


class IsActiveMember(IsAuthenticatedAnyStatus):
    def has_permission(self, request, view) -> bool:  # type: ignore[no-untyped-def]
        if not super().has_permission(request, view):
            return False
        if request.user.status == constants.SUSPENDED:
            raise Forbidden(
                "Your account is restricted. You can review the decision and appeal in Settings."
            )
        return True

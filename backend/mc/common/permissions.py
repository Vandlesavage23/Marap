from rest_framework.permissions import BasePermission


class DenyAll(BasePermission):
    """Project-wide default: every view must opt in explicitly (Bible §12.1)."""

    def has_permission(self, request, view) -> bool:  # type: ignore[no-untyped-def]
        return False

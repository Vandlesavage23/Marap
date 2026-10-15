from django.conf import settings
from django.utils.module_loading import import_string

from .base import IdentityProvider


def get_identity_provider() -> IdentityProvider:
    return import_string(settings.IDENTITY_PROVIDER)()

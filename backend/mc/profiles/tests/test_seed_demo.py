import pytest
from django.core.management import call_command
from django.core.management.base import CommandError

from mc.profiles.models import Profile

pytestmark = pytest.mark.django_db


def test_seed_demo_creates_varied_live_profiles_and_refuses_in_prod(settings):
    call_command("seed_demo", "--users", "30")
    live = Profile.objects.filter(status="live")
    assert live.count() == 30
    assert set(live.values_list("gender", flat=True)) == {"male", "female"}
    assert live.values_list("district", flat=True).distinct().count() > 3
    settings.SETTINGS_MODULE = "config.settings.prod"
    with pytest.raises(CommandError):
        call_command("seed_demo", "--users", "1")
    assert Profile.objects.count() == 30

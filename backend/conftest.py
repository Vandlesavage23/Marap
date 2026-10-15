import pytest
from django.test import Client

from mc.common.redis import get_redis


@pytest.fixture(autouse=True)
def _clean_redis():
    get_redis().flushdb()
    yield
    get_redis().flushdb()


@pytest.fixture
def api():
    """Test client bound to the api host."""
    return Client(headers={"host": "api.mc.test"})


@pytest.fixture(autouse=True)
def _fake_sms():
    from mc.accounts.providers.sms import FakeSms

    FakeSms.reset()
    yield FakeSms
    FakeSms.reset()


@pytest.fixture(autouse=True)
def _fake_identity():
    from mc.verification.providers.fake import FakeIdentityProvider

    FakeIdentityProvider.reset()
    yield FakeIdentityProvider
    FakeIdentityProvider.reset()

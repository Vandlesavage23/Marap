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

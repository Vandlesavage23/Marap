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


@pytest.fixture
def s3():
    """Real S3 API surface via moto (bucket created); storage client reset around the test."""
    import boto3
    from django.conf import settings
    from moto import mock_aws

    from mc.media import storage

    with mock_aws():
        storage.reset_client()
        client = boto3.client(
            "s3", region_name=settings.AWS_REGION, aws_access_key_id="x", aws_secret_access_key="x"
        )
        for bucket in (settings.MEDIA_BUCKET, settings.EXPORTS_BUCKET):
            client.create_bucket(
                Bucket=bucket, CreateBucketConfiguration={"LocationConstraint": settings.AWS_REGION}
            )
        yield storage
    storage.reset_client()


@pytest.fixture(autouse=True)
def _fake_media_providers():
    from mc.media.providers.moderation import FakeModeration
    from mc.media.providers.scanner import FakeScanner

    FakeModeration.reset()
    FakeScanner.unavailable = False
    yield
    FakeModeration.reset()
    FakeScanner.unavailable = False


@pytest.fixture(autouse=True)
def _fake_push():
    from mc.notifications.providers.push import FakePush

    FakePush.reset()
    yield FakePush
    FakePush.reset()


@pytest.fixture(autouse=True)
def _fake_play():
    from mc.billing.providers.google import FakePlayApi

    FakePlayApi.reset()
    yield FakePlayApi
    FakePlayApi.reset()


@pytest.fixture(autouse=True)
def _fake_gateway():
    from mc.billing.providers.flutterwave import FakeGateway

    FakeGateway.reset()
    yield FakeGateway
    FakeGateway.reset()

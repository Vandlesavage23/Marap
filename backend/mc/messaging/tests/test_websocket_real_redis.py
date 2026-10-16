"""Regression for a bug the in-memory channel layer hides: with the REAL Redis layer, redis-py's default socket timeout
killed every idle chat socket within ~5 s ("Timeout reading from redis"). Found by the local k6 run (loadtests/)."""

import asyncio

import pytest
from channels import layers
from channels.db import database_sync_to_async

from config.settings import base as base_settings

from .helpers import matched
from .test_websocket import connect

pytestmark = [pytest.mark.django_db(transaction=True), pytest.mark.asyncio]


@pytest.fixture
def real_redis_layer(settings):
    settings.CHANNEL_LAYERS = {
        "default": {
            "BACKEND": "channels_redis.core.RedisChannelLayer",
            "CONFIG": base_settings.CHANNEL_LAYERS["default"]["CONFIG"]
            | {
                "hosts": [
                    {
                        **base_settings.CHANNEL_LAYERS["default"]["CONFIG"]["hosts"][0],
                        "address": settings.REDIS_URL,
                    }
                ]
            },
        }
    }
    layers.channel_layers.backends = {}
    yield
    layers.channel_layers.backends = {}


async def test_idle_sockets_survive_and_still_receive_over_real_redis(real_redis_layer):
    m, f, mid = await database_sync_to_async(matched)()
    cm, cf = await connect(m), await connect(f)
    await asyncio.sleep(7)  # longer than channels_redis' 5 s blocking pop
    await cm.send_json_to(
        {
            "type": "msg.send",
            "match_id": mid,
            "client_msg_id": "33333333-3333-4333-8333-333333333333",
            "kind": "text",
            "body": "still alive",
        }
    )
    assert (await cm.receive_json_from(timeout=5))["type"] == "msg.ack"
    got = await cf.receive_json_from(timeout=5)
    assert got["type"] == "msg.new" and got["message"]["body"] == "still alive"
    await cm.disconnect()
    await cf.disconnect()

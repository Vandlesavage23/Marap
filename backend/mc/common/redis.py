from functools import lru_cache

import redis
from django.conf import settings


@lru_cache(maxsize=1)
def _client(url: str) -> "redis.Redis":
    return redis.Redis.from_url(url)


def get_redis() -> "redis.Redis":
    return _client(settings.REDIS_URL)

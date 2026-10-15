"""Live-socket presence in Redis. A sorted set per account scores each socket by its expiry time, so a
crashed server's sockets age out instead of keeping a user 'online' forever."""

import time
import uuid

from .redis import get_redis

TTL_SECONDS = 70  # > 2 ping intervals


def _key(account_id: uuid.UUID) -> str:
    return f"presence:{account_id}"


def touch(account_id: uuid.UUID, socket_id: str) -> None:
    r = get_redis()
    now = time.time()
    pipe = r.pipeline()
    pipe.zadd(_key(account_id), {socket_id: now + TTL_SECONDS})
    pipe.zremrangebyscore(_key(account_id), "-inf", now)
    pipe.expire(_key(account_id), TTL_SECONDS * 2)
    pipe.execute()


def remove(account_id: uuid.UUID, socket_id: str) -> None:
    get_redis().zrem(_key(account_id), socket_id)


def is_online(account_id: uuid.UUID) -> bool:
    r = get_redis()
    r.zremrangebyscore(_key(account_id), "-inf", time.time())
    return bool(r.zcard(_key(account_id)))

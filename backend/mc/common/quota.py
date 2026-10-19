"""Daily allowances kept in Redis (browse cards, profile opens): atomic "grant up to N more" with no PII.

Keys are `quota:<kind>:<HMAC of the account id>:<Kampala date>` so a Redis dump never reveals who looked at what
and a counter dies with its day. One Lua script reads, grants and increments in a single step, so concurrent
requests can never grant more than the limit between them. If Redis loses a counter the allowance simply resets,
which is acceptable for an anti-scraping / product limit (the interests quota is in Postgres, not here)."""

import uuid
from datetime import datetime

from mc.common.crypto import hmac_value
from mc.common.redis import get_redis
from mc.common.timeutil import kampala_date, next_kampala_midnight

_GRANT = """
local used = tonumber(redis.call('GET', KEYS[1]) or '0')
local want = tonumber(ARGV[1])
local limit = tonumber(ARGV[2])
local grant = math.min(want, math.max(limit - used, 0))
if grant > 0 then
  redis.call('INCRBY', KEYS[1], grant)
  redis.call('EXPIRE', KEYS[1], tonumber(ARGV[3]))
end
return grant
"""
EXPIRY_SLACK_SECONDS = 3600


def day_key(kind: str, account_id: uuid.UUID, now: datetime) -> str:
    who = hmac_value(f"quota|{account_id}", purpose="account").hex()[:32]
    return f"quota:{kind}:{who}:{kampala_date(now).isoformat()}"


def ttl_for(now: datetime) -> int:
    return int((next_kampala_midnight(now) - now).total_seconds()) + EXPIRY_SLACK_SECONDS


def consume_upto(key: str, *, want: int, limit: int, now: datetime) -> int:
    """Take up to `want` units from the allowance; returns how many were granted (0 when exhausted)."""
    if want <= 0:
        return 0
    return int(get_redis().eval(_GRANT, 1, key, want, limit, ttl_for(now)))


def used(key: str) -> int:
    return int(get_redis().get(key) or 0)


_UNIQUE = """
if redis.call('SISMEMBER', KEYS[1], ARGV[1]) == 1 then return 1 end
if redis.call('SCARD', KEYS[1]) >= tonumber(ARGV[2]) then return 0 end
redis.call('SADD', KEYS[1], ARGV[1])
redis.call('EXPIRE', KEYS[1], tonumber(ARGV[3]))
return 1
"""


def consume_unique(key: str, *, member: uuid.UUID, limit: int, now: datetime) -> bool:
    """Count one distinct `member` (e.g. a profile opened today). Opening the same one again is free; a new one
    is refused once `limit` distinct members were taken. The member is stored only as an HMAC fragment."""
    tag = hmac_value(f"quota-member|{member}", purpose="account").hex()[:16]
    return bool(int(get_redis().eval(_UNIQUE, 1, key, tag, limit, ttl_for(now))))


def used_unique(key: str) -> int:
    return int(get_redis().scard(key))

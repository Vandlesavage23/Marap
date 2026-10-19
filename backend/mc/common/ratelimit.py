"""Redis rate-limit helper (Bible §8.1, §12.1). Fixed-window counters; raises `RateLimited`
with the seconds until the window resets. Window keys are atomic (INCR then EXPIRE on first hit)."""

from .crypto import hmac_value
from .errors import RateLimited
from .redis import get_redis


def hit(bucket: str, *, limit: int, window_seconds: int) -> int:
    """Count one hit; raise RateLimited if over `limit`. Returns remaining hits in the window."""
    r = get_redis()
    key = f"rl:{bucket}"
    pipe = r.pipeline()
    pipe.incr(key)
    pipe.ttl(key)
    count, ttl = pipe.execute()
    if ttl == -1:  # first hit (or lost expiry) → start the window
        r.expire(key, window_seconds)
        ttl = window_seconds
    if count > limit:
        raise RateLimited(retry_after=max(int(ttl), 1))
    return limit - int(count)


def check_only(bucket: str, *, limit: int) -> bool:
    """True if the bucket is not yet exhausted (does not count a hit)."""
    value = get_redis().get(f"rl:{bucket}")
    return int(value or 0) < limit


def hit_client(
    kind: str, *, ip: str | None, install_id: str | None, limit: int, window_seconds: int
) -> None:
    """Per-IP and per-device allowance for `kind` (anti-scraping). Both identifiers are counted on HMACs, never
    stored raw; either one over `limit` raises `RateLimited`."""
    if ip:
        hit(
            f"{kind}:ip:{hmac_value(ip, purpose='ip').hex()[:32]}",
            limit=limit,
            window_seconds=window_seconds,
        )
    if install_id:
        hit(
            f"{kind}:device:{hmac_value(f'device|{install_id}', purpose='account').hex()[:32]}",
            limit=limit,
            window_seconds=window_seconds,
        )

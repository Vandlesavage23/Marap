"""UUIDv7 ids (RFC 9562): 48-bit unix-ms timestamp + random bits, so ids sort by creation time.

Ids are strictly monotonic within a process (two ids minted in the same millisecond still sort in
creation order) — keyset pagination relies on this.
"""

import os
import threading
import time
import uuid

_lock = threading.Lock()
_last = 0


def uuid7() -> uuid.UUID:
    global _last
    ms = time.time_ns() // 1_000_000
    rand = int.from_bytes(os.urandom(10), "big")
    value = (ms & ((1 << 48) - 1)) << 80
    value |= 0x7 << 76
    value |= ((rand >> 62) & 0xFFF) << 64
    value |= 0b10 << 62
    value |= rand & ((1 << 62) - 1)
    with _lock:
        if value <= _last:
            value = _last + 1
        _last = value
    return uuid.UUID(int=value)

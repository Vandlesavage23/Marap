"""Malware scanning (ClamAV `INSTREAM` over TCP). `FakeScanner` flags the EICAR test string."""

import socket
import struct
from pathlib import Path
from typing import Protocol

from django.conf import settings
from django.utils.module_loading import import_string

from mc.common.errors import ProviderError

EICAR = b"X5O!P%@AP[4\\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*"


class Scanner(Protocol):
    def is_clean(self, path: Path) -> bool: ...


class FakeScanner:
    unavailable = False

    def is_clean(self, path: Path) -> bool:
        if FakeScanner.unavailable:
            raise ProviderError("scanner unavailable")
        return EICAR not in path.read_bytes()


class ClamdScanner:
    CHUNK = 64 * 1024

    def is_clean(self, path: Path) -> bool:
        try:
            with socket.create_connection(
                (settings.CLAMD_HOST, settings.CLAMD_PORT), timeout=30
            ) as s:
                s.sendall(b"zINSTREAM\0")
                with path.open("rb") as f:
                    while chunk := f.read(self.CHUNK):
                        s.sendall(struct.pack("!I", len(chunk)) + chunk)
                s.sendall(struct.pack("!I", 0))
                reply = s.recv(4096)
        except OSError as exc:
            raise ProviderError("scanner unavailable") from exc
        if b"FOUND" in reply:
            return False
        if b"OK" in reply:
            return True
        raise ProviderError("unexpected scanner reply")


def get_scanner() -> Scanner:
    return import_string(settings.MALWARE_SCANNER)()

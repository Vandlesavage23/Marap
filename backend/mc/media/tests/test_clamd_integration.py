"""Runs only when a real clamd is reachable: CLAMD_TEST_HOST=127.0.0.1 CLAMD_TEST_PORT=3310
(`docker run -p 3310:3310 clamav/clamav:stable`). Verified once against clamav/clamav:stable."""

import os

import pytest

from mc.media.providers.scanner import EICAR, ClamdScanner

HOST = os.environ.get("CLAMD_TEST_HOST")
pytestmark = pytest.mark.skipif(not HOST, reason="no clamd available (set CLAMD_TEST_HOST)")


@pytest.fixture
def clamd(settings):
    settings.CLAMD_HOST, settings.CLAMD_PORT = HOST, int(os.environ.get("CLAMD_TEST_PORT", "3310"))


def test_real_clamd_flags_eicar_and_passes_clean_files(clamd, tmp_path):
    ok, bad = tmp_path / "ok.bin", tmp_path / "bad.bin"
    ok.write_bytes(b"hello world" * 5000)  # spans several INSTREAM chunks
    bad.write_bytes(EICAR)
    scanner = ClamdScanner()
    assert scanner.is_clean(ok) is True
    assert scanner.is_clean(bad) is False


def test_unreachable_clamd_is_a_provider_error(settings, tmp_path):
    from mc.common.errors import ProviderError

    settings.CLAMD_HOST, settings.CLAMD_PORT = "127.0.0.1", 1
    f = tmp_path / "x"
    f.write_bytes(b"x")
    with pytest.raises(ProviderError):
        ClamdScanner().is_clean(f)

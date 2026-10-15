"""Untrusted-file processing (Bible §9.3 step 4). Everything here treats the input as hostile:
real type from content (libmagic), pixel-count guard, decode → re-encode so nothing from the original
container (EXIF, trailing bytes, polyglot payloads) survives."""

import json
import subprocess
from dataclasses import dataclass
from pathlib import Path

import magic
import pyvips
from django.conf import settings

ALLOWED_IMAGE_MIMES = {"image/jpeg", "image/png", "image/webp"}
ALLOWED_AUDIO_MIMES = {
    "audio/mp4",
    "audio/aac",
    "audio/mpeg",
    "audio/ogg",
    "audio/webm",
    "audio/x-m4a",
    "audio/wav",
    "audio/x-wav",
    "video/mp4",
    "video/webm",
    "application/ogg",
    "audio/x-hx-aac-adts",
}
# libmagic reports m4a/webm/ogg variously; the declared type from the client is checked against the
# image/audio *family*, and ffprobe is the final arbiter for audio.


class Rejected(Exception):
    def __init__(self, reason: str) -> None:
        super().__init__(reason)
        self.reason = reason


@dataclass(frozen=True)
class ProcessedImage:
    data: bytes
    width: int
    height: int


@dataclass(frozen=True)
class ProcessedAudio:
    data: bytes
    duration_ms: int


def sniff_mime(path: Path) -> str:
    return str(magic.from_file(str(path), mime=True))


def process_image(path: Path) -> ProcessedImage:
    mime = sniff_mime(path)
    if mime not in ALLOWED_IMAGE_MIMES:
        raise Rejected("unsupported_type")
    try:
        probe = pyvips.Image.new_from_file(str(path), access="sequential", fail=True)
        if probe.width * probe.height > settings.MEDIA_IMAGE_MAX_PIXELS:
            raise Rejected("too_many_pixels")
        # Decode fully (autorotate applies EXIF orientation *before* metadata is stripped).
        image = pyvips.Image.new_from_file(str(path), fail=True).autorot()
        edge = settings.MEDIA_IMAGE_MAX_EDGE
        if max(image.width, image.height) > edge:
            image = image.thumbnail_image(edge, height=edge, size="down")
        if image.hasalpha():
            image = image.flatten(background=[255, 255, 255])
        if image.interpretation not in ("srgb", "b-w"):
            image = image.colourspace("srgb")
        data = image.write_to_buffer(".webp", Q=82, strip=True)
        return ProcessedImage(data=bytes(data), width=image.width, height=image.height)
    except Rejected:
        raise
    except pyvips.Error as exc:
        raise Rejected("corrupt_image") from exc


def _probe(path: Path) -> dict:
    out = subprocess.run(  # noqa: S603
        [
            "ffprobe", "-v", "error", "-protocol_whitelist", "file", "-show_entries",
            "format=duration:stream=codec_type", "-of", "json", str(path),
        ],
        capture_output=True, timeout=20, check=False,
    )  # fmt: skip
    if out.returncode != 0:
        raise Rejected("corrupt_audio")
    try:
        return json.loads(out.stdout)
    except ValueError as exc:
        raise Rejected("corrupt_audio") from exc


def process_audio(path: Path, out_path: Path) -> ProcessedAudio:
    info = _probe(path)
    if not any(s.get("codec_type") == "audio" for s in info.get("streams", [])):
        raise Rejected("no_audio_stream")
    if any(s.get("codec_type") == "video" for s in info.get("streams", [])):
        raise Rejected("unsupported_type")
    try:
        duration = float(info["format"]["duration"])
    except (KeyError, ValueError, TypeError) as exc:
        raise Rejected("corrupt_audio") from exc
    if duration > settings.MEDIA_VOICE_MAX_SECONDS + 0.5:
        raise Rejected("too_long")
    result = subprocess.run(  # noqa: S603
        [
            "ffmpeg", "-nostdin", "-v", "error", "-protocol_whitelist", "file", "-i", str(path),
            "-t", str(settings.MEDIA_VOICE_MAX_SECONDS), "-vn", "-map_metadata", "-1",
            "-c:a", "aac", "-b:a", "48k", "-ac", "1", "-f", "ipod", "-y", str(out_path),
        ],
        capture_output=True, timeout=60, check=False,
    )  # fmt: skip
    if result.returncode != 0:
        raise Rejected("corrupt_audio")
    data = out_path.read_bytes()
    if len(data) > settings.MEDIA_VOICE_MAX_BYTES:
        raise Rejected("too_large")
    return ProcessedAudio(
        data=data, duration_ms=int(min(duration, settings.MEDIA_VOICE_MAX_SECONDS) * 1000)
    )

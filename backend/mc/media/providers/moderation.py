"""Image moderation (Bible §11.5). Hosted API behind an interface; text is never sent to a model."""

import hashlib
from dataclasses import dataclass, field
from pathlib import Path
from typing import ClassVar, Protocol

from django.conf import settings
from django.utils.module_loading import import_string


@dataclass(frozen=True)
class ModerationResult:
    nudity: bool = False
    violence: bool = False
    minor_suspected: bool = False
    face_count: int = 0
    labels: list[str] = field(default_factory=list)


class ImageModerationProvider(Protocol):
    def analyse(self, path: Path) -> ModerationResult: ...


class FakeModeration:
    """Scriptable: map a sha256 to a result; unknown images are clean with one face."""

    scripted: ClassVar[dict[str, ModerationResult]] = {}
    default: ClassVar[ModerationResult] = ModerationResult(face_count=1)

    def analyse(self, path: Path) -> ModerationResult:
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        return self.scripted.get(digest, self.default)

    @classmethod
    def reset(cls) -> None:
        cls.scripted.clear()


class RekognitionModeration:
    """AWS Rekognition (moderation labels + face age range). UNVERIFIED against AWS — evaluate with a
    second vendor in MC-061 before launch."""

    def analyse(self, path: Path) -> ModerationResult:  # pragma: no cover - needs AWS
        import boto3

        client = boto3.client(
            "rekognition", region_name=settings.MODERATION_AWS_REGION or settings.AWS_REGION
        )
        image = {"Bytes": path.read_bytes()}
        labels = client.detect_moderation_labels(Image=image, MinConfidence=80)["ModerationLabels"]
        names = sorted(
            {lab["Name"] for lab in labels} | {lab.get("ParentName", "") for lab in labels} - {""}
        )
        faces = client.detect_faces(Image=image, Attributes=["ALL"])["FaceDetails"]
        minor = any(f["AgeRange"]["Low"] < 16 for f in faces)
        return ModerationResult(
            nudity=any(n in ("Explicit Nudity", "Nudity") for n in names),
            violence=any(n in ("Violence", "Visually Disturbing") for n in names),
            minor_suspected=minor,
            face_count=len(faces),
            labels=names,
        )


def get_moderation_provider() -> ImageModerationProvider:
    return import_string(settings.IMAGE_MODERATION_PROVIDER)()

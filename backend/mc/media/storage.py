"""S3-compatible object storage (AWS S3 / MinIO). Private buckets only; never public URLs."""

import tempfile
from dataclasses import dataclass
from functools import lru_cache
from typing import Any

import boto3
from botocore.client import Config
from botocore.exceptions import ClientError
from django.conf import settings


@dataclass(frozen=True)
class PresignedPost:
    url: str
    fields: dict[str, str]


@lru_cache(maxsize=1)
def _client() -> Any:
    return boto3.client(
        "s3",
        endpoint_url=settings.AWS_S3_ENDPOINT_URL or None,
        region_name=settings.AWS_REGION,
        aws_access_key_id=settings.AWS_ACCESS_KEY_ID or None,
        aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY or None,
        config=Config(signature_version="s3v4", s3={"addressing_style": "path"}),
    )


def reset_client() -> None:  # tests
    _client.cache_clear()


def presign_post(*, key: str, content_type: str, max_bytes: int, ttl: int = 300) -> PresignedPost:
    """Presigned POST so S3 itself enforces `content-length-range` and the content type (a presigned
    PUT cannot enforce size)."""
    resp = _client().generate_presigned_post(
        Bucket=settings.MEDIA_BUCKET,
        Key=key,
        Fields={"Content-Type": content_type},
        Conditions=[
            {"Content-Type": content_type},
            ["content-length-range", 1, max_bytes],
        ],
        ExpiresIn=ttl,
    )
    return PresignedPost(url=resp["url"], fields=resp["fields"])


def presign_get(*, key: str, ttl: int = 600) -> str:
    return str(
        _client().generate_presigned_url(
            "get_object", Params={"Bucket": settings.MEDIA_BUCKET, "Key": key}, ExpiresIn=ttl
        )
    )


def head_size(key: str) -> int | None:
    try:
        return int(_client().head_object(Bucket=settings.MEDIA_BUCKET, Key=key)["ContentLength"])
    except ClientError:
        return None


def download_to_tempfile(key: str, *, suffix: str = "") -> Any:
    tmp = tempfile.NamedTemporaryFile(suffix=suffix)  # noqa: SIM115 - caller closes
    _client().download_fileobj(settings.MEDIA_BUCKET, key, tmp)
    tmp.flush()
    return tmp


def put_bytes(key: str, data: bytes, content_type: str) -> None:
    extra = {"ServerSideEncryption": settings.MEDIA_SSE} if settings.MEDIA_SSE else {}
    _client().put_object(
        Bucket=settings.MEDIA_BUCKET, Key=key, Body=data, ContentType=content_type, **extra
    )


def delete(key: str) -> None:
    _client().delete_object(Bucket=settings.MEDIA_BUCKET, Key=key)


def put_file(key: str, path: str, content_type: str, *, bucket: str | None = None) -> None:
    extra = {"ServerSideEncryption": settings.MEDIA_SSE} if settings.MEDIA_SSE else {}
    _client().upload_file(
        path, bucket or settings.MEDIA_BUCKET, key, ExtraArgs={"ContentType": content_type, **extra}
    )


def presign_get_in(*, bucket: str, key: str, ttl: int) -> str:
    return str(
        _client().generate_presigned_url(
            "get_object", Params={"Bucket": bucket, "Key": key}, ExpiresIn=ttl
        )
    )


def delete_in(*, bucket: str, key: str) -> None:
    _client().delete_object(Bucket=bucket, Key=key)


def read_bytes(key: str) -> bytes | None:
    """Object contents, or None if it no longer exists (never fail a whole export for one missing file)."""
    try:
        return bytes(_client().get_object(Bucket=settings.MEDIA_BUCKET, Key=key)["Body"].read())
    except ClientError as exc:
        if exc.response.get("Error", {}).get("Code") in ("NoSuchKey", "404"):
            return None
        raise

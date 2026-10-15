"""Data export (MC-111): a JSON file + the member's own media in a zip, delivered through a signed link that
expires after 7 days. Contents are limited to the member's own data plus conversations they were part of;
nothing else about other people (no profiles, phones or photos)."""

import json
import tempfile
import uuid
import zipfile
from datetime import datetime, timedelta

from django.conf import settings
from django.db import transaction
from django.utils import timezone

from mc.accounts import selectors as account_selectors
from mc.billing import selectors as billing_selectors
from mc.common.errors import Conflict, NotFound
from mc.entitlements import selectors as entitlement_selectors
from mc.interests import selectors as interest_selectors
from mc.matches import selectors as match_selectors  # noqa: F401
from mc.media import services as media_services
from mc.media import storage
from mc.messaging import selectors as messaging_selectors
from mc.notifications import selectors as notification_selectors
from mc.notifications import services as notification_services
from mc.profiles import selectors as profile_selectors
from mc.questionnaire import selectors as questionnaire_selectors
from mc.safety import selectors as safety_selectors
from mc.verification import selectors as verification_selectors

from .models import PrivacyRequest


def request_export(*, account) -> PrivacyRequest:  # type: ignore[no-untyped-def]
    """One open export at a time (a repeat returns it). The build runs on the worker."""
    from .tasks import build_export

    now = timezone.now()
    with transaction.atomic():
        existing = PrivacyRequest.objects.filter(
            account_ref=account.id, kind="export", status="pending"
        ).first()
        if existing:
            return existing
        req = PrivacyRequest.objects.create(
            account=account, account_ref=account.id, kind="export", requested_at=now,
            due_at=now + timedelta(hours=settings.PRIVACY_EXPORT_SLA_HOURS),
        )  # fmt: skip
        transaction.on_commit(lambda: build_export.delay(str(req.id)))
    return req


def collect(account) -> dict[str, object]:  # type: ignore[no-untyped-def]
    return {
        "generated_at": timezone.now().isoformat(),
        "account": account_selectors.export_for_account(account),
        "profile": profile_selectors.export_for_account(account),
        "questionnaire_answers": questionnaire_selectors.export_for_account(account),
        "verification": verification_selectors.export_for_account(account),
        "membership": entitlement_selectors.export_for_account(account),
        "purchases": billing_selectors.export_for_account(account),
        "interests": interest_selectors.export_for_account(account),
        "conversations": messaging_selectors.export_for_account(account),
        "safety": safety_selectors.export_for_account(account),
        "notifications": notification_selectors.export_for_account(account),
        "note": "Messages are included only for conversations you were part of. Other members' profiles are not part of your data.",
    }


def build(*, request_id: uuid.UUID) -> PrivacyRequest | None:
    req = PrivacyRequest.objects.filter(id=request_id, kind="export").first()
    if req is None or req.status != "pending":
        return req
    account = account_selectors.get_account(req.account_ref)
    if account is None:
        PrivacyRequest.objects.filter(id=req.id).update(status="cancelled")
        return req
    data = collect(account)
    with tempfile.NamedTemporaryFile(suffix=".zip") as tmp:
        with zipfile.ZipFile(tmp.name, "w", zipfile.ZIP_DEFLATED) as z:
            z.writestr("data.json", json.dumps(data, indent=2, default=str))
            for name, blob in media_services.export_files_for(account_id=account.id):
                z.writestr(name, blob)
        key = f"exports/{req.id}.zip"
        storage.put_file(key, tmp.name, "application/zip", bucket=settings.EXPORTS_BUCKET)
    now = timezone.now()
    PrivacyRequest.objects.filter(id=req.id).update(
        status="completed", completed_at=now, file_key=key,
        expires_at=now + timedelta(days=settings.PRIVACY_EXPORT_LINK_DAYS), updated_at=now,
    )  # fmt: skip
    notification_services.notify(
        account_id=account.id, type="export_ready", payload={"request_id": req.id}
    )
    req.refresh_from_db()
    return req


def signed_link(*, account, request_id: uuid.UUID) -> tuple[str, datetime]:  # type: ignore[no-untyped-def]
    """A fresh short-lived download URL for the member's own finished export (404 once expired/foreign)."""
    req = PrivacyRequest.objects.filter(
        id=request_id, account_ref=account.id, kind="export"
    ).first()
    if req is None:
        raise NotFound()
    if (
        req.status != "completed"
        or not req.file_key
        or (req.expires_at and req.expires_at <= timezone.now())
    ):
        raise Conflict("This export isn't available.")
    url = storage.presign_get_in(bucket=settings.EXPORTS_BUCKET, key=req.file_key, ttl=3600)
    return url, req.expires_at  # type: ignore[return-value]


def purge_expired(*, now: datetime | None = None) -> int:
    """Retention job: delete export files after the link window."""
    now = now or timezone.now()
    n = 0
    for req in PrivacyRequest.objects.filter(
        kind="export", status="completed", expires_at__lte=now
    ).exclude(file_key=""):
        media_services.delete_export_object(key=req.file_key)
        PrivacyRequest.objects.filter(id=req.id).update(file_key="", updated_at=now)
        n += 1
    return n

"""Closed-beta controls (MC-127): invite codes, feedback and per-district go-live throttles. All thresholds come from
settings/DB, never from code paths in other modules."""

import secrets
import uuid

from django.conf import settings
from django.db import IntegrityError, transaction
from django.db.models import F
from django.utils import timezone

from mc.audit import services as audit
from mc.common.errors import Conflict, ValidationFailed
from mc.common.timeutil import kampala_date

from .models import BetaFeedback, DistrictCap, InviteCode, InviteRedemption

ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  # no look-alikes
BAD_INVITE = "That invite code isn't valid."


def _norm(code: str) -> str:
    return "".join(ch for ch in code.upper() if ch.isalnum())


def invite_required() -> bool:
    return bool(settings.BETA_INVITE_REQUIRED)


def _usable(inv: InviteCode | None) -> bool:
    return bool(
        inv
        and inv.active
        and inv.uses < inv.max_uses
        and (inv.expires_at is None or inv.expires_at > timezone.now())
    )


def assert_invite_valid(code: str | None) -> None:
    """Read-only pre-check so a bad code is rejected before the SMS code is spent."""
    inv = InviteCode.objects.filter(code=_norm(code or "")).first()
    if not _usable(inv):
        raise ValidationFailed(BAD_INVITE, invite_code="invalid")


def redeem_invite(*, code: str | None, account_id: uuid.UUID) -> None:
    """Atomically consume one use. Raises (and rolls back the caller's transaction) if the code is unusable."""
    with transaction.atomic():
        inv = InviteCode.objects.select_for_update().filter(code=_norm(code or "")).first()
        if inv is None or not _usable(inv):
            raise ValidationFailed(BAD_INVITE, invite_code="invalid")
        try:
            with transaction.atomic():
                InviteRedemption.objects.create(invite=inv, account_id=account_id)
        except IntegrityError:
            return  # this account already redeemed (retry)
        InviteCode.objects.filter(pk=inv.pk).update(uses=F("uses") + 1)


def create_invites(
    *,
    count: int,
    max_uses: int = 1,
    expires_at=None,
    note: str = "",
    created_by: uuid.UUID | None = None,
) -> list[str]:
    if not 1 <= count <= 1000 or max_uses < 1:
        raise ValidationFailed("Invalid invite batch.")
    codes: list[str] = []
    with transaction.atomic():
        while len(codes) < count:
            code = "".join(secrets.choice(ALPHABET) for _ in range(8))
            if InviteCode.objects.filter(code=code).exists() or code in codes:
                continue
            InviteCode.objects.create(
                code=code,
                max_uses=max_uses,
                expires_at=expires_at,
                note=note[:120],
                created_by=created_by,
            )
            codes.append(code)
        audit.record(
            actor_type="staff" if created_by else "system", actor_id=created_by, action="beta.invites_created",
            reason=note or "beta invites", metadata={"count": str(count), "max_uses": str(max_uses)},
        )  # fmt: skip
    return codes


def submit_feedback(
    *,
    account_id: uuid.UUID,
    message: str,
    screen: str = "",
    rating: int | None = None,
    app_version: str = "",
) -> BetaFeedback:
    message = message.strip()
    if not 3 <= len(message) <= 2000:
        raise ValidationFailed("Feedback must be 3-2,000 characters.")
    if rating is not None and not 1 <= rating <= 5:
        raise ValidationFailed("Rating must be 1-5.")
    return BetaFeedback.objects.create(
        account_id=account_id,
        message=message,
        screen=screen[:40],
        rating=rating,
        app_version=app_version[:32],
    )


def claim_go_live(*, district: str) -> None:
    """Called inside the go-live transaction. Raises `Conflict` (code signups_paused) when the district is paused or
    today's cap is used up; the claim rolls back with the transaction if go-live then fails."""
    today = kampala_date(timezone.now())
    with transaction.atomic():
        cap = DistrictCap.objects.select_for_update().filter(district=district).first()
        if cap is None:
            return
        if cap.paused:
            raise SignupsPaused()
        if cap.count_date != today:
            cap.count_date, cap.count = today, 0
        if cap.daily_cap is not None and cap.count >= cap.daily_cap:
            raise SignupsPaused()
        cap.count += 1
        cap.save(update_fields=["count_date", "count", "updated_at"])


class SignupsPaused(Conflict):
    code, status, title = "signups_paused", 409, "Sign-ups paused"

    def __init__(self) -> None:
        super().__init__(
            "We're letting people in gradually in your area. Please try again tomorrow."
        )


def set_district_cap(
    *, district: str, daily_cap: int | None, paused: bool, actor_id: uuid.UUID | None = None
) -> DistrictCap:
    with transaction.atomic():
        cap, _ = DistrictCap.objects.update_or_create(
            district=district, defaults={"daily_cap": daily_cap, "paused": paused}
        )
        audit.record(
            actor_type="staff" if actor_id else "system", actor_id=actor_id, action="beta.district_cap",
            reason=district, metadata={"daily_cap": str(daily_cap), "paused": str(paused)},
        )  # fmt: skip
    return cap


def purge_for(account_id: uuid.UUID) -> None:
    InviteRedemption.objects.filter(account_id=account_id).delete()
    BetaFeedback.objects.filter(account_id=account_id).delete()

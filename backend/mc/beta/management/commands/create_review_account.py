"""Create (or refresh) the single app-store review account: a verified, live member with 60 days of membership.
Requires REVIEW_ACCOUNT_PHONE/REVIEW_ACCOUNT_CODE to be configured. Audited. Never run it with real personal data."""

from datetime import timedelta

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from django.utils import timezone

from mc.accounts import selectors as account_selectors
from mc.audit import services as audit
from mc.entitlements import services as entitlement_services


class Command(BaseCommand):
    help = "Provision the store-review demo account (see docs/release/store-submission.md)."

    def add_arguments(self, parser):  # type: ignore[no-untyped-def]
        parser.add_argument("--confirm", action="store_true", required=True)

    def handle(self, *args, **opts):  # type: ignore[no-untyped-def]
        phone, code = settings.REVIEW_ACCOUNT_PHONE, settings.REVIEW_ACCOUNT_CODE
        if not phone or not code:
            raise CommandError("Set REVIEW_ACCOUNT_PHONE and REVIEW_ACCOUNT_CODE first.")
        from devtools import factories  # synthetic member builder (no real data)

        account = account_selectors.get_account_by_phone(phone)
        if account is None:
            account = factories.create_member(
                phone=phone, name="Review Demo", gender="female", age=29
            )
        entitlement_services.grant(
            account=account, ends_at=timezone.now() + timedelta(days=60), reason="store review account",
            actor_id=account.id, actor_role="system",
        )  # fmt: skip
        audit.record(
            actor_type="system",
            action="beta.review_account_provisioned",
            target_type="account",
            target_id=account.id,
            reason="store review",
        )
        self.stdout.write("Review account ready.")

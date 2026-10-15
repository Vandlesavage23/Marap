from datetime import timedelta

from django.core.management.base import BaseCommand
from django.utils import timezone

from mc.beta import services


class Command(BaseCommand):
    help = "Create closed-beta invite codes (printed one per line)."

    def add_arguments(self, parser):  # type: ignore[no-untyped-def]
        parser.add_argument("--count", type=int, default=10)
        parser.add_argument("--uses", type=int, default=1)
        parser.add_argument("--expires-days", type=int, default=30)
        parser.add_argument("--note", default="")

    def handle(self, *args, **o):  # type: ignore[no-untyped-def]
        exp = timezone.now() + timedelta(days=o["expires_days"]) if o["expires_days"] else None
        for code in services.create_invites(
            count=o["count"], max_uses=o["uses"], expires_at=exp, note=o["note"]
        ):
            self.stdout.write(code)

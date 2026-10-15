from django.core.management.base import BaseCommand, CommandError

from mc.privacy import inventory


class Command(BaseCommand):
    help = "Fail if any model field lacks a row in docs/privacy/data-inventory.csv (Bible §12.2)."

    def handle(self, *args, **opts) -> None:  # type: ignore[no-untyped-def]
        gaps = inventory.missing()
        if gaps:
            raise CommandError("Fields without a data-inventory row:\n  " + "\n  ".join(gaps))
        self.stdout.write("data inventory is complete")

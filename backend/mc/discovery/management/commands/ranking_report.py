import json

from django.core.management.base import BaseCommand

from mc.discovery import evaluation


class Command(BaseCommand):
    help = "Ranking evaluation: mutual-interest rate and exposure Gini by gender / age band / district."

    def add_arguments(self, parser) -> None:  # type: ignore[no-untyped-def]
        parser.add_argument("--days", type=int, default=30)

    def handle(self, *args, **opts) -> None:  # type: ignore[no-untyped-def]
        self.stdout.write(json.dumps(evaluation.report(days=opts["days"]), indent=2, default=str))

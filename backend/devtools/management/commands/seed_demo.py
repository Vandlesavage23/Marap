"""Create varied, verified, live demo members (MC-023). local/dev only.

uv run python manage.py seed_demo --users 500 [--seed 7]
"""

import random
from datetime import timedelta

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from django.utils import timezone

from devtools import factories
from mc.questionnaire.models import Question

ALLOWED = ("config.settings.local", "config.settings.dev", "config.settings.test")
FEMALE = ["Amina", "Grace", "Sarah", "Ruth", "Esther", "Joy", "Mercy", "Faith", "Naomi", "Lydia"]
MALE = ["David", "Peter", "Moses", "Daniel", "Isaac", "Samuel", "Joel", "Brian", "Emma", "Paul"]


class Command(BaseCommand):
    help = "Create N verified, live, varied demo members. Refuses to run outside local/dev."

    def add_arguments(self, parser) -> None:  # type: ignore[no-untyped-def]
        parser.add_argument("--users", type=int, default=500)
        parser.add_argument("--seed", type=int, default=7)

    def handle(self, *args, **opts):  # type: ignore[no-untyped-def]
        if settings.SETTINGS_MODULE not in ALLOWED:
            raise CommandError("seed_demo only runs in local/dev.")
        if not Question.objects.filter(is_core=True).exists():
            raise CommandError("Run migrate first (questions are missing).")
        rng = random.Random(opts["seed"])
        now = timezone.now()
        for i in range(opts["users"]):
            gender = "female" if i % 2 == 0 else "male"
            age = min(60, max(18, int(rng.gauss(30, 6))))
            factories.create_member(
                gender=gender,
                age=age,
                district=factories.random_district(rng),
                name=f"{rng.choice(FEMALE if gender == 'female' else MALE)} {i + 1}",
                answer_values=factories.default_answer_values(rng),
                importance=rng.choice([1, 2, 3]),
                has_children=rng.choice(["no", "no", "yes"]),
                photos=rng.choice([1, 2, 3]),
                last_seen_at=now - timedelta(hours=rng.randint(0, 24 * 20)),
                created_at=now - timedelta(days=rng.randint(0, 60)),
            )
        self.stdout.write(f"Created {opts['users']} demo members.")

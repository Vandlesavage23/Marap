"""Synthetic benchmark + EXPLAIN for the hard-filter query (MC-055). Refuses to run unless DEBUG/local.

DATABASE_URL=postgres://mc:mc@localhost/mc_bench uv run python manage.py migrate
DATABASE_URL=... uv run python manage.py bench_hard_filter --profiles 100000
"""

import random
import time
import uuid
from datetime import timedelta

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from django.db import connection
from django.utils import timezone

from mc.accounts.models import Account
from mc.common.ids import uuid7
from mc.profiles import search
from mc.profiles.districts import UGANDA_DISTRICTS
from mc.profiles.models import Preference, Profile


class Command(BaseCommand):
    help = "Create N synthetic live profiles in an EMPTY scratch database and EXPLAIN ANALYZE the hard filter."

    def add_arguments(self, parser) -> None:  # type: ignore[no-untyped-def]
        parser.add_argument("--profiles", type=int, default=100_000)
        parser.add_argument("--out", default="")

    def handle(self, *args, **opts) -> None:  # type: ignore[no-untyped-def]
        if not settings.DEBUG:
            raise CommandError("Refusing to run outside local/dev settings.")
        if Account.objects.exists():
            raise CommandError("Database is not empty; use a scratch database.")
        rng = random.Random(7)
        n = opts["profiles"]
        today = timezone.localdate()
        now = timezone.now()
        accounts, profiles, prefs = [], [], []
        for i in range(n):
            aid = uuid7()
            age = rng.randint(18, 60)
            accounts.append(
                Account(
                    id=aid,
                    phone_e164=f"+2567{i:09d}",
                    status="active",
                    last_seen_at=now - timedelta(hours=rng.randint(0, 720)),
                )
            )
            gender = "female" if i % 2 else "male"
            pid = uuid7()
            district = rng.choice(UGANDA_DISTRICTS)
            profiles.append(
                Profile(
                    id=pid, account_id=aid, display_name=f"M{i}", gender=gender,
                    birth_date=today.replace(year=today.year - age) if not (today.month == 2 and today.day == 29) else today.replace(year=today.year - age, day=28),
                    district=district, status="live", marital_status="never_married", has_children=rng.choice(["no", "no", "yes_living_with_me"]),
                    location_lat=round(rng.uniform(-1, 3.5), 2), location_lng=round(rng.uniform(29.5, 35), 2),
                )
            )  # fmt: skip
            prefs.append(
                Preference(
                    id=uuid7(),
                    profile_id=pid,
                    age_min=max(18, age - 7),
                    age_max=min(80, age + 10),
                    max_distance_km=None,
                )
            )
        t = time.time()
        Account.objects.bulk_create(accounts, batch_size=5000)
        Profile.objects.bulk_create(profiles, batch_size=5000)
        Preference.objects.bulk_create(prefs, batch_size=5000)
        with connection.cursor() as cur:
            cur.execute("ANALYZE")
        self.stdout.write(f"loaded {n} profiles in {time.time() - t:.1f}s")

        viewer = Profile.objects.filter(gender="male").order_by("id").first()
        if viewer is None:
            raise CommandError("No male profile created.")
        report = []
        for label, max_km in (("no distance limit", None), ("max_distance_km=50", 50)):
            pref = Preference.objects.get(profile=viewer)
            pref.max_distance_km = max_km
            ctx = search.viewer_context(viewer, pref)
            if max_km:
                from dataclasses import replace

                ctx = replace(ctx, lat=0.35, lng=32.58)
            base = search.candidate_queryset(ctx)
            from django.db.models import F

            qs = base.order_by(F("account__last_seen_at").desc(nulls_last=True), "id").values(
                "id", "account_id", "district", "created_at"
            )[:500]
            sql, params = qs.query.sql_with_params()
            with connection.cursor() as cur:
                cur.execute("EXPLAIN (ANALYZE, BUFFERS) " + sql, params)
                plan = "\n".join(r[0] for r in cur.fetchall())
            started = time.time()
            rows = list(qs)
            report.append((label, len(rows), (time.time() - started) * 1000, plan))
        text = [f"# MC-055 hard-filter EXPLAIN ({n:,} synthetic live profiles)\n"]
        for label, count, ms, plan in report:
            text.append(f"## {label}: {count} rows, {ms:.0f} ms wall\n\n```\n{plan}\n```\n")
        out = "\n".join(text)
        if opts["out"]:
            with open(opts["out"], "w") as f:
                f.write(out)
        self.stdout.write(out)
        _ = uuid

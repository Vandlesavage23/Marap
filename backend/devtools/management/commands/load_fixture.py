"""Bulk fixture for load tests (loadtests/). local/dev/test only.

    uv run python manage.py load_fixture --users 2000 --pairs 400 --out tokens.json

Creates N verified, live members with a membership (half men, half women), P matched pairs with a few messages, and
writes `[{access, account_id, profile_id, match_id|null}]` with real sessions. Tokens last ACCESS_TOKEN_MINUTES, so set
that high when running a long test. Never run against shared data."""

import json
import random
import uuid
from datetime import timedelta

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from django.utils import timezone

from devtools import factories
from mc.accounts import services as account_services
from mc.accounts import tokens
from mc.entitlements.models import Entitlement
from mc.interests import services as interest_services
from mc.messaging import services as messaging_services
from mc.profiles.models import Profile
from mc.questionnaire.models import Question

ALLOWED = (
    "config.settings.local",
    "config.settings.dev",
    "config.settings.test",
    "devtools.contract_settings",
)


class Command(BaseCommand):
    help = "Create bulk members, matches and tokens for load tests."

    def add_arguments(self, parser) -> None:  # type: ignore[no-untyped-def]
        parser.add_argument("--users", type=int, default=2000)
        parser.add_argument("--pairs", type=int, default=400)
        parser.add_argument("--out", required=True)
        parser.add_argument("--seed", type=int, default=3)

    def handle(self, *args, **o):  # type: ignore[no-untyped-def]
        if settings.SETTINGS_MODULE not in ALLOWED:
            raise CommandError("load_fixture only runs in local/dev/test.")
        if not Question.objects.filter(is_core=True).exists():
            raise CommandError("Run migrate first.")
        n, pairs = o["users"], o["pairs"]
        if pairs * 2 > n:
            raise CommandError("--pairs needs at least 2x users.")
        rng = random.Random(o["seed"])
        now = timezone.now()
        men, women = [], []
        for i in range(n):
            gender = "male" if i % 2 == 0 else "female"
            paired = i // 2 < pairs  # pairs share age and district so they are mutually eligible
            age = 26 + (i // 2) % 5 if paired else min(55, max(19, int(rng.gauss(30, 6))))
            district = "Kampala" if paired else factories.random_district(rng)
            acct = factories.create_member(
                gender=gender, age=age, district=district,
                answer_values=factories.default_answer_values(rng), photos=1, last_seen_at=now,
            )  # fmt: skip
            Entitlement.objects.create(
                account=acct, source=Entitlement.Source.GRANT, starts_at=now - timedelta(hours=1),
                ends_at=now + timedelta(days=30), reason="load fixture",
            )  # fmt: skip
            (men if gender == "male" else women).append(acct)
        match_of: dict[str, str] = {}
        for i in range(pairs):
            m, w = men[i], women[i]
            interest_services.send_interest(
                sender=m,
                recipient_profile_id=Profile.objects.get(account=w).id,
                idempotency_key=f"lf-{i}-a",
            )
            res = interest_services.send_interest(
                sender=w,
                recipient_profile_id=Profile.objects.get(account=m).id,
                idempotency_key=f"lf-{i}-b",
            )
            for k in range(3):
                messaging_services.send_message(
                    sender=m if k % 2 == 0 else w, match_id=res["match_id"], client_msg_id=uuid.UUID(f"00000000-0000-4000-8000-{i:06d}{k:06d}"),
                    kind="text", body=f"seed message {k}",
                )  # fmt: skip
            match_of[str(m.id)] = match_of[str(w.id)] = str(res["match_id"])
        out = []
        for acct in [*men, *women]:
            session, _ = account_services._create_session(account=acct, device=None)
            out.append(
                {
                    "access": tokens.issue_access_token(account_id=acct.id, session_id=session.id),
                    "account_id": str(acct.id),
                    "profile_id": str(Profile.objects.get(account=acct).id),
                    "match_id": match_of.get(str(acct.id)),
                }
            )
        with open(o["out"], "w", encoding="utf-8") as fh:
            json.dump(out, fh)
        self.stdout.write(f"wrote {len(out)} tokens ({len(match_of)} in matches)")

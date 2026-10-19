"""Deterministic fixture for the mobile contract tests (apps/mobile/test/contract). local/test only.

    uv run python manage.py contract_fixture [--reset]

Creates (does NOT migrate; run `migrate` first so the seeded questions exist):
  ben     verified live man with a grant membership, matched with amina (a few messages, one unread)
  amina   verified live woman with a grant membership
  peter   verified live man with a membership; has a PENDING interest to amina
  grace   verified live woman, discoverable by ben (target for "send interest")
  joy     verified live woman, target for block/report
  newbie  verified live man WITHOUT any membership: a free member (v2: browses, 3 interests / week, trial start)
  unverif a signed-in UNVERIFIED man: consents given, "About you" done (name, gender, birth date, district),
          no description/photos/answers, account `pending_verification` (limited cards, locked profiles,
          verification_required on send_interest)
  quota   verified live FREE man with 2 of his 3 weekly interests already used (pending, to qpeer1/qpeer2);
          one more send works, then `interest_quota_reached`; qpeer3/qpeer4 are his targets
  qpeer1..qpeer4  verified live women (quota member's targets)
  scout   verified live man with a membership that only browses discovery
  bulka/bulkb  a matched pair with an empty conversation (pagination, rate limit)
  lapsed/lapsedpeer  a match whose member's membership ended (v2: the conversation stays writable)
  locka/lockb  a matched pair with no messages and photos locked
  picka/pickb  a matched pair with 10 messages each (photos unlocked)
and prints one JSON document with access/refresh tokens, account and profile ids.
Tokens are real: a Session row exists for each, so refresh/logout/sessions endpoints work.
"""

import json
import random
import uuid
from datetime import timedelta

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from django.utils import timezone

from devtools import factories
from mc.accounts import services as account_services
from mc.accounts import tokens
from mc.accounts.models import Account
from mc.entitlements.models import Entitlement
from mc.interests import services as interest_services
from mc.messaging import services as messaging_services
from mc.notifications import services as notification_services
from mc.profiles.models import Description, Preference, Profile
from mc.questionnaire.models import Question

ALLOWED = (
    "config.settings.local",
    "config.settings.dev",
    "config.settings.test",
    "devtools.contract_settings",
)
NS = uuid.UUID("6f0f4a52-0000-4000-8000-00000000c0de")

MEMBERS = {
    #          phone            gender    age  name              membership
    "ben": ("+256771000001", "male", 31, "Ben Contract", True),
    "amina": ("+256771000002", "female", 28, "Amina Contract", True),
    "peter": ("+256771000003", "male", 33, "Peter Contract", True),
    "grace": ("+256771000004", "female", 29, "Grace Contract", False),
    "joy": ("+256771000005", "female", 27, "Joy Contract", False),
    "newbie": ("+256771000006", "male", 30, "Newbie Contract", False),
    # Only ever browses (discovery tests); nobody sends it interests or blocks it.
    "scout": ("+256771000007", "male", 32, "Scout Contract", True),
    # A matched pair with an empty conversation, for pagination / rate-limit tests.
    "bulka": ("+256771000008", "male", 34, "Bulk A Contract", True),
    "bulkb": ("+256771000009", "female", 30, "Bulk B Contract", True),
    # A member whose membership has ended (v2: chat in the match stays free) and their match partner.
    "lapsed": ("+256771000014", "male", 37, "Lapsed Contract", True),
    "lapsedpeer": ("+256771000015", "female", 33, "Lapsed Peer Contract", True),
    # A matched pair that never exchanges messages here: photos stay locked.
    "locka": ("+256771000012", "male", 36, "Lock A Contract", True),
    "lockb": ("+256771000013", "female", 32, "Lock B Contract", True),
    # A matched pair that has already exchanged enough messages to unlock photos.
    "picka": ("+256771000010", "male", 35, "Pick A Contract", True),
    "pickb": ("+256771000011", "female", 31, "Pick B Contract", True),
    # v2 states: a free member with the weekly quota nearly used and the women he can still / cannot yet send to.
    "quota": ("+256771000017", "male", 30, "Quota Contract", False),
    "qpeer1": ("+256771000018", "female", 28, "Quota Peer One", False),
    "qpeer2": ("+256771000019", "female", 29, "Quota Peer Two", False),
    "qpeer3": ("+256771000020", "female", 27, "Quota Peer Three", False),
    "qpeer4": ("+256771000021", "female", 28, "Quota Peer Four", False),
}
# A signed-in member who has not verified: built by hand below (no live profile, no answers).
UNVERIFIED = ("unverif", "+256771000016", "male", 29, "Unverified Contract")


def _cid(label: str) -> uuid.UUID:
    return uuid.uuid5(NS, label)


class Command(BaseCommand):
    help = "Create the deterministic contract-test fixture and print tokens as JSON."

    def _unverified_member(self, now) -> Account:  # type: ignore[no-untyped-def]
        """Signed in, consents given, "About you" done; nothing else (no description, photos, answers)."""
        _key, phone, gender, age, name = UNVERIFIED
        account = factories.create_member(
            gender=gender,
            age=age,
            name=name,
            phone=phone,
            district="Kampala",
            verified=False,
            live=False,
            photos=0,
            with_answers=False,
            last_seen_at=now,
        )
        Profile.objects.filter(account=account).update(current_description=None, completeness=0)
        Description.objects.filter(profile__account=account).delete()
        Preference.objects.filter(profile__account=account).delete()
        account_services.record_consent(
            account=account,
            items=[
                {"kind": kind, "version": "2026-01", "granted": True}
                for kind in ("terms", "privacy", "data_transfer")
            ],
            source="app",
        )
        return account

    def add_arguments(self, parser) -> None:  # type: ignore[no-untyped-def]
        parser.add_argument("--reset", action="store_true", help="Delete a previous fixture first.")
        parser.add_argument(
            "--out", default="", help="Also write the JSON to this file (logs share stdout)."
        )

    def handle(self, *args, **opts):  # type: ignore[no-untyped-def]
        if settings.SETTINGS_MODULE not in ALLOWED:
            raise CommandError("contract_fixture only runs in local/dev/test.")
        if not Question.objects.filter(is_core=True).exists():
            raise CommandError("Run migrate first (questions are missing).")
        phones = [m[0] for m in MEMBERS.values()] + [UNVERIFIED[1]]
        if (
            settings.REVIEW_ACCOUNT_PHONE
        ):  # created by the onboarding contract test via the review OTP
            phones.append(settings.REVIEW_ACCOUNT_PHONE)
        existing = Account.objects.filter(phone_e164__in=phones)
        if existing.exists():
            if not opts["reset"]:
                raise CommandError("Fixture accounts exist; pass --reset.")
            for account in existing:
                account_services.hard_delete_account(account=account)

        rng = random.Random(11)
        base_answers = factories.default_answer_values(rng)
        accounts: dict[str, Account] = {}
        with transaction.atomic():
            now = timezone.now()
            for key, (phone, gender, age, name, member) in MEMBERS.items():
                accounts[key] = factories.create_member(
                    gender=gender,
                    age=age,
                    name=name,
                    phone=phone,
                    district="Kampala",
                    answer_values=base_answers,
                    photos=2,
                    last_seen_at=now,
                )
                if member:
                    Entitlement.objects.create(
                        account=accounts[key],
                        source=Entitlement.Source.GRANT,
                        starts_at=now - timedelta(hours=1),
                        ends_at=now + timedelta(days=30),
                        reason="contract fixture",
                    )

        accounts["unverif"] = self._unverified_member(now)
        ben, amina, peter = accounts["ben"], accounts["amina"], accounts["peter"]
        quota = accounts["quota"]
        for peer in ("qpeer1", "qpeer2"):  # 2 of the 3 free weekly interests are already spent
            interest_services.send_interest(
                sender=quota,
                recipient_profile_id=Profile.objects.get(account=accounts[peer]).id,
                idempotency_key=f"fixture-quota-{peer}",
            )
        # ben <-> amina: mutual interest -> match.
        interest_services.send_interest(
            sender=ben,
            recipient_profile_id=Profile.objects.get(account=amina).id,
            idempotency_key="fixture-ben-amina",
        )
        res = interest_services.send_interest(
            sender=amina,
            recipient_profile_id=Profile.objects.get(account=ben).id,
            idempotency_key="fixture-amina-ben",
        )
        match_id = res["match_id"]
        if match_id is None:
            raise CommandError("Expected a match between ben and amina.")
        for who, text, label in (
            (ben, "Hello Amina, nice to meet you.", "m1"),
            (amina, "Hello Ben, good to meet you too.", "m2"),
            (amina, "How was your week?", "m3"),
        ):
            messaging_services.send_message(
                sender=who,
                match_id=match_id,
                client_msg_id=_cid(label),
                kind="text",
                body=text,
            )
        bulka, bulkb = accounts["bulka"], accounts["bulkb"]
        interest_services.send_interest(
            sender=bulka,
            recipient_profile_id=Profile.objects.get(account=bulkb).id,
            idempotency_key="fixture-bulka-bulkb",
        )
        bulk = interest_services.send_interest(
            sender=bulkb,
            recipient_profile_id=Profile.objects.get(account=bulka).id,
            idempotency_key="fixture-bulkb-bulka",
        )
        lapsed, lapsedpeer = accounts["lapsed"], accounts["lapsedpeer"]
        interest_services.send_interest(
            sender=lapsed,
            recipient_profile_id=Profile.objects.get(account=lapsedpeer).id,
            idempotency_key="fixture-lapsed-peer",
        )
        lapsed_match = interest_services.send_interest(
            sender=lapsedpeer,
            recipient_profile_id=Profile.objects.get(account=lapsed).id,
            idempotency_key="fixture-peer-lapsed",
        )
        for who, text, label in (
            (lapsed, "Hello, before my membership ended.", "l1"),
            (lapsedpeer, "Hello back, still here.", "l2"),
        ):
            messaging_services.send_message(
                sender=who,
                match_id=lapsed_match["match_id"],
                client_msg_id=_cid(label),
                kind="text",
                body=text,
            )
        # the membership ends AFTER the match and messages exist (scenario 06: read-only, no data loss)
        Entitlement.objects.filter(account=lapsed).update(
            starts_at=now - timedelta(days=40), ends_at=now - timedelta(days=1)
        )
        locka, lockb = accounts["locka"], accounts["lockb"]
        interest_services.send_interest(
            sender=locka,
            recipient_profile_id=Profile.objects.get(account=lockb).id,
            idempotency_key="fixture-locka-lockb",
        )
        locked = interest_services.send_interest(
            sender=lockb,
            recipient_profile_id=Profile.objects.get(account=locka).id,
            idempotency_key="fixture-lockb-locka",
        )
        picka, pickb = accounts["picka"], accounts["pickb"]
        interest_services.send_interest(
            sender=picka,
            recipient_profile_id=Profile.objects.get(account=pickb).id,
            idempotency_key="fixture-picka-pickb",
        )
        photo = interest_services.send_interest(
            sender=pickb,
            recipient_profile_id=Profile.objects.get(account=picka).id,
            idempotency_key="fixture-pickb-picka",
        )
        for i in range(10):  # photos unlock once each side has sent 10 messages
            for who in (picka, pickb):
                messaging_services.send_message(
                    sender=who,
                    match_id=photo["match_id"],
                    client_msg_id=_cid(f"photo-{who.id}-{i}"),
                    kind="text",
                    body=f"Warm-up message {i}",
                )
        # peter -> amina stays pending.
        pending = interest_services.send_interest(
            sender=peter,
            recipient_profile_id=Profile.objects.get(account=amina).id,
            idempotency_key="fixture-peter-amina",
        )["interest"]
        notification_services.notify(
            account_id=ben.id,
            type="trial_ending_soon",
            payload={"fixture": "1"},
        )

        out: dict[str, object] = {
            "api_host": "api.mc.test",
            "review_phone": settings.REVIEW_ACCOUNT_PHONE,
            "review_code": settings.REVIEW_ACCOUNT_CODE,
            "match_id": str(match_id),
            "bulk_match_id": str(bulk["match_id"]),
            "photo_match_id": str(photo["match_id"]),
            "locked_match_id": str(locked["match_id"]),
            "lapsed_match_id": str(lapsed_match["match_id"]),
            "pending_interest_id": str(pending.id),
            "match_other_member": "amina",
            "members": {},
        }
        members: dict[str, object] = {}
        for key, account in accounts.items():
            session, refresh = account_services._create_session(account=account, device=None)
            other, _ = account_services._create_session(account=account, device=None)
            # Refreshing rotates the session, which kills the access token bound to it. Tests that
            # exercise refresh therefore get their own sessions ("slots") so they cannot log other
            # tests out. The access JWT of each slot is already expired.
            slots = []
            for _slot in range(2):
                s_slot, r_slot = account_services._create_session(account=account, device=None)
                slots.append(
                    {
                        "session_id": str(s_slot.id),
                        "refresh": r_slot,
                        "access": tokens.issue_access_token(
                            account_id=account.id,
                            session_id=s_slot.id,
                            now=timezone.now()
                            - timedelta(minutes=settings.ACCESS_TOKEN_MINUTES + 60),
                        ),
                    }
                )
            members[key] = {
                "second_session_id": str(other.id),
                "expired_slots": slots,
                "name": MEMBERS[key][3] if key in MEMBERS else UNVERIFIED[4],
                "phone": account.phone_e164,
                "account_id": str(account.id),
                "profile_id": str(Profile.objects.get(account=account).id),
                "session_id": str(session.id),
                "access": tokens.issue_access_token(account_id=account.id, session_id=session.id),
                "refresh": refresh,
            }
        out["members"] = members
        text = json.dumps(out)
        if opts["out"]:
            with open(opts["out"], "w", encoding="utf-8") as fh:
                fh.write(text)
        self.stdout.write(text)  # last line of stdout

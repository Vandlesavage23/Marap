"""Disclosure eligibility (Bible §18). Ineligible until the flag is on; when built it will use
`Match.first_two_way_message_at` + 14 days, consent, an active match and no block. The reserved Postgres
schema for the (future) sensitive tables is `sensitive`; no tables exist yet."""

import enum
import uuid
from dataclasses import dataclass
from datetime import datetime
from typing import Protocol

from mc.phase5 import gate

DB_SCHEMA = "sensitive"  # reserved, nothing is created in it
MIN_DAYS_AFTER_FIRST_TWO_WAY_MESSAGE = 14


class Outcome(enum.StrEnum):
    ELIGIBLE = "eligible"
    INELIGIBLE = "ineligible"


@dataclass(frozen=True)
class Decision:
    outcome: Outcome
    reason: str = ""

    @property
    def eligible(self) -> bool:
        return self.outcome is Outcome.ELIGIBLE


class MatchLike(Protocol):
    status: str
    first_two_way_message_at: datetime | None


class MemberLike(Protocol):
    id: uuid.UUID


class DisclosureEligibility(Protocol):
    def check(self, match: MatchLike, viewer: MemberLike, subject: MemberLike) -> Decision: ...


class DisabledDisclosureEligibility:
    """The only implementation: always ineligible (the flag is locked off)."""

    def check(self, match: MatchLike, viewer: MemberLike, subject: MemberLike) -> Decision:
        if not gate.is_enabled(gate.DISCLOSURE):
            return Decision(Outcome.INELIGIBLE, "feature_disabled")
        return Decision(Outcome.INELIGIBLE, "not_built")


def get_eligibility() -> DisclosureEligibility:
    return DisabledDisclosureEligibility()

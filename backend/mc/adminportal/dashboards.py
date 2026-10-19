"""Staff dashboards (Bible §15): date-range handling, the registration funnel and SLA badges. The numbers come from
aggregate-only selectors in the owning modules (small cells already suppressed there); nothing here touches a member
row, so no personal data can reach these pages."""

from dataclasses import dataclass
from datetime import date, datetime, timedelta
from typing import Any

from mc.accounts import selectors as account_selectors
from mc.common import aggregates
from mc.common.timeutil import KAMPALA, kampala_date
from mc.entitlements import selectors as entitlement_selectors
from mc.interests import selectors as interest_selectors
from mc.matches import selectors as match_selectors
from mc.profiles import selectors as profile_selectors
from mc.verification import selectors as verification_selectors

DEFAULT_DAYS = 30
MAX_DAYS = 366
DUE_SOON = timedelta(hours=1)


@dataclass(frozen=True)
class DateRange:
    first: date  # inclusive, Kampala calendar days
    last: date  # inclusive
    error: str = ""

    @property
    def start(self) -> datetime:
        return datetime(self.first.year, self.first.month, self.first.day, tzinfo=KAMPALA)

    @property
    def end(self) -> datetime:
        """Exclusive upper bound: midnight after `last`."""
        nxt = self.last + timedelta(days=1)
        return datetime(nxt.year, nxt.month, nxt.day, tzinfo=KAMPALA)


def parse_range(raw_from: str, raw_to: str, *, now: datetime) -> DateRange:
    """`from`/`to` query values (YYYY-MM-DD). Anything unusable falls back to the last 30 days with an error message."""
    today = kampala_date(now)
    default = DateRange(today - timedelta(days=DEFAULT_DAYS - 1), today)
    if not raw_from and not raw_to:
        return default
    try:
        first = date.fromisoformat(raw_from) if raw_from else default.first
        last = date.fromisoformat(raw_to) if raw_to else today
    except ValueError:
        return DateRange(default.first, default.last, "Dates must look like 2026-03-31.")
    # Snap to whole ISO weeks (Mon-Sun): arbitrary day ranges could be subtracted from each other to recover a single
    # day's cohort below the small-cell threshold (OPEN_QUESTIONS Q30).
    first -= timedelta(days=first.weekday())
    last += timedelta(days=6 - last.weekday())
    last = min(last, today)  # nothing can have happened after today
    if first > last:
        return DateRange(default.first, default.last, "The start date is after the end date.")
    if (last - first).days + 1 > MAX_DAYS:
        return DateRange(default.first, default.last, f"Pick a range of at most {MAX_DAYS} days.")
    return DateRange(first, last)


FUNNEL_STAGES = (
    ("registered", "Registered"),
    ("verified", "Verified"),
    ("live", "Live profile"),
    ("first_interest", "Sent a first interest"),
    ("first_match", "In a first match"),
    ("member", "Paying member"),
)


def funnel(rng: DateRange) -> list[dict[str, Any]]:
    """The cohort funnel: of the accounts registered in the range, how many reached each stage (at any time since).
    A stage count below the suppression threshold is `None`; percentages are only given when both counts are shown."""
    kw = {"start": rng.start, "end": rng.end}
    counts = {
        "registered": account_selectors.funnel_registered_count(**kw),
        "verified": verification_selectors.funnel_verified_count(**kw),
        "live": profile_selectors.funnel_live_count(**kw),
        "first_interest": interest_selectors.funnel_first_interest_count(**kw),
        "first_match": match_selectors.funnel_first_match_count(**kw),
        "member": entitlement_selectors.funnel_member_count(**kw),
    }
    rows: list[dict[str, Any]] = []
    registered = counts["registered"]
    previous: int | None = None
    for i, (key, title) in enumerate(FUNNEL_STAGES):
        n = counts[key]
        rows.append(
            {
                "key": key,
                "title": title,
                "count": n,
                "text": aggregates.label(n),
                "of_registered": _pct(n, registered) if i else None,
                "of_previous": _pct(n, previous) if i else None,
            }
        )
        previous = n
    return rows


APP_STEP_TITLES = {
    "welcome_seen": "Saw the welcome screen",
    "otp_sent": "Asked for a sign-in code",
    "otp_verified": "Signed in",
    "about_done": "Finished About you",
    "first_card_seen": "Saw a first member card",
    "profile_opened": "Opened a profile",
    "verify_started": "Started verification",
    "verify_passed": "Passed verification",
    "golive_done": "Went live",
    "first_interest": "Sent a first interest",
    "paywall_seen": "Saw the membership offer",
    "trial_started": "Started the free trial",
}


def app_funnel(rng: DateRange) -> list[dict[str, Any]]:
    """The in-app step funnel: distinct installs that reached each step for the first time in the range (anonymous
    installs identified only by an HMAC of a random id). Same small-cell suppression as the cohort funnel; the
    percentage compares with the first step shown, only when both cells are visible."""
    counts = account_selectors.funnel_step_counts(start=rng.start, end=rng.end)
    first = next(iter(counts.values()), None)
    rows: list[dict[str, Any]] = []
    previous: int | None = None
    for i, (key, n) in enumerate(counts.items()):
        rows.append(
            {
                "key": key,
                "title": APP_STEP_TITLES.get(key, key),
                "count": n,
                "text": aggregates.label(n),
                "of_first": _pct(n, first) if i else None,
                "of_previous": _pct(n, previous) if i else None,
            }
        )
        previous = n
    return rows


def _pct(n: int | None, base: int | None) -> str | None:
    if n is None or not base:
        return None
    return f"{100 * n / base:.0f}%"


def sla_badge(due_at: datetime, *, now: datetime) -> dict[str, str]:
    """`{state, text}` for a queue row: `overdue` / `soon` (due within an hour) / `ok`."""
    delta = due_at - now
    if delta.total_seconds() < 0:
        return {"state": "overdue", "text": f"Overdue by {_span(-delta)}"}
    return {"state": "soon" if delta <= DUE_SOON else "ok", "text": f"Due in {_span(delta)}"}


def _span(delta: timedelta) -> str:
    minutes = int(delta.total_seconds() // 60)
    days, rest = divmod(minutes, 1440)
    hours, mins = divmod(rest, 60)
    if days:
        return f"{days}d {hours}h"
    if hours:
        return f"{hours}h {mins}m"
    return f"{mins}m"


def queue_summary(due_dates: list[datetime], *, now: datetime) -> dict[str, int]:
    return {
        "open": len(due_dates),
        "overdue": sum(1 for d in due_dates if d < now),
        "soon": sum(1 for d in due_dates if now <= d <= now + DUE_SOON),
    }

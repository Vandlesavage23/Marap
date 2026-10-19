from datetime import UTC, date, datetime, timedelta
from zoneinfo import ZoneInfo

KAMPALA = ZoneInfo("Africa/Kampala")


def kampala_date(moment: datetime) -> date:
    return moment.astimezone(KAMPALA).date()


def age_on(dob: date, on: date) -> int:
    return on.year - dob.year - ((on.month, on.day) < (dob.month, dob.day))


def start_of_kampala_day(now: datetime) -> datetime:
    d = kampala_date(now)
    return datetime(d.year, d.month, d.day, tzinfo=KAMPALA)


def next_kampala_midnight(now: datetime) -> datetime:
    """Start of the next Kampala calendar day (when daily counters reset)."""
    return start_of_kampala_day(now) + timedelta(days=1)


def iso_z(moment: datetime) -> str:
    """ISO-8601 UTC with a `Z` suffix and whole seconds (the API's timestamp format)."""
    return moment.astimezone(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")

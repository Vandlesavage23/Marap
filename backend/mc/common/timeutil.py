from datetime import date, datetime
from zoneinfo import ZoneInfo

KAMPALA = ZoneInfo("Africa/Kampala")


def kampala_date(moment: datetime) -> date:
    return moment.astimezone(KAMPALA).date()


def age_on(dob: date, on: date) -> int:
    return on.year - dob.year - ((on.month, on.day) < (dob.month, dob.day))


def start_of_kampala_day(now: datetime) -> datetime:
    d = kampala_date(now)
    return datetime(d.year, d.month, d.day, tzinfo=KAMPALA)

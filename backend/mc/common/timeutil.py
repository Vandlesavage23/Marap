from datetime import date, datetime
from zoneinfo import ZoneInfo

KAMPALA = ZoneInfo("Africa/Kampala")


def kampala_date(moment: datetime) -> date:
    return moment.astimezone(KAMPALA).date()


def age_on(dob: date, on: date) -> int:
    return on.year - dob.year - ((on.month, on.day) < (dob.month, dob.day))

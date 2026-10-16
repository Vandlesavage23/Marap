"""Small-cell suppression for aggregate dashboards (Bible §15): a count below `AGGREGATE_MIN_CELL` is never
returned, so a staff member can't learn that, say, exactly two live members are in a district."""

from django.conf import settings


def suppress(count: int) -> int | None:
    """`count` if it is large enough to show, else None (render as "<5")."""
    return count if count >= settings.AGGREGATE_MIN_CELL else None


def label(value: int | None) -> str:
    """Display form of a (possibly suppressed) cell."""
    return str(value) if value is not None else f"<{settings.AGGREGATE_MIN_CELL}"

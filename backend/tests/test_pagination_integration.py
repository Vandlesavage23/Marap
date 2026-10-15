import base64  # noqa: F401

import pytest

from mc.audit.models import AuditEvent
from mc.common import errors, pagination

pytestmark = pytest.mark.django_db

# ---- pagination ----------------------------------------------------------


def _make_events(n):
    return [AuditEvent.objects.create(actor_type="system", action=f"t.{i}") for i in range(n)]


def test_pagination_walks_all_pages_without_dupes():
    made = _make_events(25)
    seen, cursor = [], None
    while True:
        page = pagination.paginate(AuditEvent.objects.all(), cursor=cursor, limit=10)
        seen += [e.id for e in page.items]
        cursor = page.next_cursor
        if not cursor:
            break
    assert len(seen) == 25 and len(set(seen)) == 25
    assert seen == [e.id for e in reversed(made)]


def test_pagination_stable_under_concurrent_inserts():
    _make_events(12)
    first = pagination.paginate(AuditEvent.objects.all(), cursor=None, limit=5)
    _make_events(5)  # new rows arrive after page 1 was served
    second = pagination.paginate(AuditEvent.objects.all(), cursor=first.next_cursor, limit=5)
    assert not {e.id for e in first.items} & {e.id for e in second.items}


def test_pagination_rejects_garbage_cursor_and_limit():
    with pytest.raises(errors.ValidationFailed):
        pagination.decode_cursor("not-a-cursor")
    with pytest.raises(errors.ValidationFailed):
        pagination.parse_limit("abc")
    assert pagination.parse_limit("500") == pagination.MAX_LIMIT
    assert pagination.parse_limit(None) == pagination.DEFAULT_LIMIT


def test_pagination_last_page_has_null_cursor():
    _make_events(3)
    page = pagination.paginate(AuditEvent.objects.all(), cursor=None, limit=10)
    assert page.next_cursor is None and len(page.items) == 3
    assert page.as_dict(lambda e: str(e.id))["next_cursor"] is None

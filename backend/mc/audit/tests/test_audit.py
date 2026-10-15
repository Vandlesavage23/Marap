import uuid

import pytest
from django.db import InternalError, connection, transaction
from django.db.utils import IntegrityError

from mc.audit import selectors, services
from mc.audit.models import AuditEvent

pytestmark = pytest.mark.django_db


def _event():
    return services.record(
        actor_type="staff",
        actor_id=uuid.uuid4(),
        role="support",
        action="admin.view",
        target_type="account",
        target_id=uuid.uuid4(),
        reason="ticket 42",
        ip="10.0.0.1",
    )


def test_record_stores_event_and_hashes_ip():
    e = _event()
    assert AuditEvent.objects.count() == 1
    assert bytes(e.ip_hmac) != b"10.0.0.1" and len(bytes(e.ip_hmac)) == 32


def test_update_raises_at_db_level():
    e = _event()
    with pytest.raises((InternalError, IntegrityError)), transaction.atomic():
        AuditEvent.objects.filter(id=e.id).update(action="tampered")


def test_orm_save_update_raises():
    e = _event()
    e.action = "tampered"
    with pytest.raises((InternalError, IntegrityError)), transaction.atomic():
        e.save()


def test_delete_raises_at_db_level():
    e = _event()
    with pytest.raises((InternalError, IntegrityError)), transaction.atomic():
        e.delete()
    with pytest.raises((InternalError, IntegrityError)), transaction.atomic():
        with connection.cursor() as cur:
            cur.execute("DELETE FROM audit_auditevent")
    assert AuditEvent.objects.filter(id=e.id).exists()


def test_search_by_target():
    e = _event()
    _event()
    assert list(selectors.search(target_id=e.target_id)) == [e]

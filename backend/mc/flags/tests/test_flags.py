import threading
import uuid
from unittest import mock

import pytest
from django.db import connection
from django.test import Client

from mc.audit.models import AuditEvent
from mc.common.errors import Forbidden, ValidationFailed
from mc.common.redis import get_redis
from mc.flags import registry, selectors, services
from mc.flags.models import FeatureFlag

pytestmark = pytest.mark.django_db
STAFF = uuid.uuid4()


def flip(key="voice_notes", enabled=False, role="engineer_oncall", reason="test change", **kw):
    return services.set_flag(
        key=key, enabled=enabled, staff_id=STAFF, role=role, reason=reason, **kw
    )


# ---------------------------------------------------------------- reads
def test_defaults_come_from_settings_when_there_is_no_row(settings):
    settings.FEATURE_FLAGS_DEFAULT = {**settings.FEATURE_FLAGS_DEFAULT, "voice_notes": False}
    assert selectors.flag_enabled("voice_notes") is False
    settings.FEATURE_FLAGS_DEFAULT = {**settings.FEATURE_FLAGS_DEFAULT, "voice_notes": True}
    assert selectors.flag_enabled("voice_notes") is True
    assert selectors.flag_enabled("data_saver_default_on_cellular") is True
    assert selectors.flag_enabled("no_such_flag") is False


def test_a_database_override_wins_and_is_cached():
    flip("voice_notes", False)
    assert selectors.flag_enabled("voice_notes") is False
    assert get_redis().get(selectors.CACHE_KEY) is not None
    # the cached value serves reads without touching the database
    with mock.patch.object(
        FeatureFlag.objects, "values_list", side_effect=AssertionError("db hit")
    ):
        assert selectors.flag_enabled("voice_notes") is False


def test_cache_is_invalidated_when_a_change_commits(django_capture_on_commit_callbacks):
    with django_capture_on_commit_callbacks(execute=True):
        flip("voice_notes", False)
    assert selectors.flag_enabled("voice_notes") is False  # now cached as off
    with django_capture_on_commit_callbacks(execute=True):
        flip("voice_notes", True)
    assert get_redis().get(selectors.CACHE_KEY) is None  # dropped on commit
    assert selectors.flag_enabled("voice_notes") is True


def test_a_reader_refilling_the_cache_before_commit_is_corrected_on_commit(
    django_capture_on_commit_callbacks,
):
    flip("voice_notes", False)
    with django_capture_on_commit_callbacks(execute=False) as callbacks:
        flip("voice_notes", True)
        get_redis().set(
            selectors.CACHE_KEY, '{"voice_notes": false}'
        )  # stale refill from another worker
    for cb in callbacks:
        cb()
    assert selectors.flag_enabled("voice_notes") is True


def test_safe_when_the_cache_is_down():
    flip("voice_notes", False)
    boom = mock.Mock(side_effect=ConnectionError("redis down"))
    with mock.patch(
        "mc.flags.selectors.get_redis", return_value=mock.Mock(get=boom, set=boom, delete=boom)
    ):
        assert selectors.flag_enabled("voice_notes") is False  # from the database
        selectors.invalidate()  # never raises
        assert selectors.flag_enabled("data_saver_default_on_cellular") is True


def test_safe_when_cache_and_database_are_down(settings):
    boom = mock.Mock(side_effect=ConnectionError("down"))
    with (
        mock.patch(
            "mc.flags.selectors.get_redis", return_value=mock.Mock(get=boom, set=boom, delete=boom)
        ),
        mock.patch.object(FeatureFlag.objects, "values_list", side_effect=RuntimeError("db down")),
    ):
        assert (
            selectors.flag_enabled("voice_notes") is settings.FEATURE_FLAGS_DEFAULT["voice_notes"]
        )
        assert selectors.flag_enabled("phase5_disclosure") is False


def test_garbage_in_the_cache_is_ignored():
    flip("voice_notes", False)
    get_redis().set(selectors.CACHE_KEY, "not json")
    assert selectors.flag_enabled("voice_notes") is False
    get_redis().set(selectors.CACHE_KEY, "[1, 2]")
    assert selectors.flag_enabled("voice_notes") is False


def test_phase5_flags_are_off_even_if_a_row_somehow_says_on():
    for key in registry.LOCKED_OFF:
        FeatureFlag.objects.create(key=key, enabled=True)
    selectors.invalidate()
    assert all(selectors.flag_enabled(k) is False for k in registry.LOCKED_OFF)
    assert all(
        not f["enabled"] and f["locked"]
        for f in selectors.all_flags()
        if f["key"] in registry.LOCKED_OFF
    )


# ---------------------------------------------------------------- writes
def test_set_flag_audits_who_what_and_why():
    flag, changed = flip("voice_notes", False, reason="  incident 42  ", ip="10.0.0.9")
    assert changed and flag.enabled is False and flag.updated_by == STAFF
    ev = AuditEvent.objects.get(action="config.flag_set")
    assert (ev.actor_type, ev.actor_id, ev.role, ev.target_id) == (
        "staff",
        STAFF,
        "engineer_oncall",
        flag.id,
    )
    assert ev.reason == "incident 42" and ev.metadata == {
        "key": "voice_notes",
        "from": True,
        "to": False,
    }
    assert ev.ip_hmac and "10.0.0.9" not in str(ev.metadata)


def test_a_reason_is_required():
    for blank in ("", "   "):
        with pytest.raises(ValidationFailed):
            flip("voice_notes", False, reason=blank)
    assert not FeatureFlag.objects.exists()


def test_setting_the_current_value_is_a_no_op_without_an_audit_row():
    flip("voice_notes", False)
    _, changed = flip("voice_notes", False)
    assert changed is False and AuditEvent.objects.filter(action="config.flag_set").count() == 1
    # a first "set" to the current default is also a no-op and does not pin the value with a new row
    _, changed = flip("data_saver_default_on_cellular", True)
    assert changed is False and AuditEvent.objects.filter(action="config.flag_set").count() == 1
    assert not FeatureFlag.objects.filter(key="data_saver_default_on_cellular").exists()


@pytest.mark.parametrize(
    "role",
    [
        "support",
        "trust_safety",
        "payments_ops",
        "privacy_officer",
        "verification_reviewer",
        "",
        "nonsense",
    ],
)
def test_only_config_roles_may_change_flags(role):
    with pytest.raises(Forbidden):
        flip("voice_notes", False, role=role)
    assert (
        not FeatureFlag.objects.exists()
        and not AuditEvent.objects.filter(action="config.flag_set").exists()
    )


def test_roles_match_the_admin_policy_matrix():
    from mc.adminportal import policies

    granted = {r for r, perms in policies.PERMISSIONS.items() if "config.flags" in perms}
    assert granted == set(services.FLAG_ROLES)
    flip("voice_notes", False, role="superadmin")


def test_unknown_keys_are_rejected_and_ranking_model_keys_are_allowed():
    for bad in (
        "",
        "typo",
        "ranking_model_v",
        "ranking_model_v0",
        "ranking_model_vx",
        "ranking_model_v1234",
        "x" * 80,
    ):
        with pytest.raises(ValidationFailed):
            flip(bad, True)
    flag, changed = flip("ranking_model_v7", True)
    assert changed and selectors.flag_enabled("ranking_model_v7") is True
    assert flag.description == "Use discovery ranking model v7."
    assert selectors.flag_enabled("ranking_model_v8") is False


def test_phase5_flags_cannot_be_switched_on_but_can_be_confirmed_off():
    for key in registry.LOCKED_OFF:
        with pytest.raises(Forbidden):
            flip(key, True, role="superadmin")
    assert not FeatureFlag.objects.exists()
    _, changed = flip("phase5_disclosure", False)
    assert changed is False


@pytest.mark.django_db(transaction=True)
def test_concurrent_first_writes_end_on_one_row_and_consistent_audit():
    results: list[bool] = []
    errors: list[Exception] = []

    def run(value: bool) -> None:
        try:
            flip("ranking_model_v2", value)
            results.append(True)
        except Exception as exc:  # pragma: no cover - failure path
            errors.append(exc)
        finally:
            connection.close()

    threads = [threading.Thread(target=run, args=(i % 2 == 0,)) for i in range(6)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    assert not errors
    assert FeatureFlag.objects.filter(key="ranking_model_v2").count() == 1
    final = FeatureFlag.objects.get(key="ranking_model_v2").enabled
    # the audit trail replays to the final value
    trail = list(AuditEvent.objects.filter(action="config.flag_set").order_by("id"))
    assert trail and trail[-1].metadata["to"] is final


# ---------------------------------------------------------------- consumers
def test_voice_notes_policy_follows_the_runtime_flag():
    from mc.messaging.tests.helpers import matched, say
    from mc.messaging.tests.test_messages import ready_chat_media

    m, f, mid = matched()
    note = ready_chat_media(m[2], purpose="voice_note")
    flip("voice_notes", False)
    off = say(m, mid, kind="voice", media_id=str(note.id))
    assert off.status_code == 422 and "Voice notes" in off.json()["detail"]
    flip("voice_notes", True)
    assert say(m, mid, kind="voice", media_id=str(note.id)).status_code == 201


# ---------------------------------------------------------------- API
def test_public_flags_endpoint_is_anonymous_allowlisted_and_live():
    c = Client(headers={"host": "api.mc.test"})
    body = c.get("/api/v1/config/flags")
    assert body.status_code == 200 and body["Cache-Control"] == "public, max-age=60"
    assert body.json() == {"flags": {"voice_notes": True, "data_saver_default_on_cellular": True}}
    flip("voice_notes", False)
    flip("ranking_model_v2", True)
    after = c.get("/api/v1/config/flags").json()["flags"]
    assert after == {"voice_notes": False, "data_saver_default_on_cellular": True}
    assert "phase5_disclosure" not in str(after) and "ranking" not in str(after)


def test_public_flags_endpoint_only_allows_get():
    c = Client(headers={"host": "api.mc.test"})
    assert c.post("/api/v1/config/flags", {}, content_type="application/json").status_code == 405
    assert c.delete("/api/v1/config/flags").status_code == 405

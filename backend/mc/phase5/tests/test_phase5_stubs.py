"""Phase 5 (CLAUDE.md rule 12, Bible §18): interfaces only, flags off, nothing reachable."""

import ast
import uuid
from datetime import UTC, datetime
from pathlib import Path
from types import SimpleNamespace

import pytest
from django.apps import apps
from django.conf import settings
from django.test import Client
from django.urls import get_resolver

from mc.common.errors import Forbidden, NotFound
from mc.flags import registry, selectors, services
from mc.flags.models import FeatureFlag
from mc.phase5 import gate
from mc.phase5.counselling import interfaces as counselling
from mc.phase5.disclosure import interfaces as disclosure
from mc.phase5.duediligence import interfaces as due_diligence

ROOT = Path(__file__).resolve().parents[2]  # backend/mc
PHASE5 = ROOT / "phase5"
ALLOWED_FILES = {"__init__.py", "interfaces.py", "gate.py"}
pytestmark = pytest.mark.django_db


def test_flags_are_off_by_default_and_locked():
    for flag in gate.ALL_FLAGS:
        assert settings.FEATURE_FLAGS_DEFAULT[flag] is False
        assert gate.is_enabled(flag) is False
        assert flag in registry.LOCKED_OFF
    assert set(gate.ALL_FLAGS) == registry.LOCKED_OFF


def test_flags_stay_off_even_if_forced_in_the_database_and_cannot_be_enabled_by_staff():
    for flag in gate.ALL_FLAGS:
        FeatureFlag.objects.create(key=flag, enabled=True)
    selectors.invalidate()
    assert not any(gate.is_enabled(f) for f in gate.ALL_FLAGS)
    for flag in gate.ALL_FLAGS:
        with pytest.raises(Forbidden):
            services.set_flag(
                key=flag, enabled=True, staff_id=uuid.uuid4(), role="superadmin", reason="try"
            )


def test_not_enabled_looks_like_an_unknown_resource():
    with pytest.raises(gate.NotEnabled) as exc:
        gate.require_enabled(gate.DISCLOSURE)
    assert (
        isinstance(exc.value, NotFound)
        and exc.value.status == 404
        and exc.value.code == "not_found"
    )


def test_disclosure_is_always_ineligible():
    match = SimpleNamespace(
        status="active", first_two_way_message_at=datetime(2020, 1, 1, tzinfo=UTC)
    )
    a, b = SimpleNamespace(id=uuid.uuid4()), SimpleNamespace(id=uuid.uuid4())
    decision = disclosure.get_eligibility().check(match, a, b)
    assert decision == disclosure.Decision(disclosure.Outcome.INELIGIBLE, "feature_disabled")
    assert decision.eligible is False
    assert (
        disclosure.DB_SCHEMA == "sensitive"
        and disclosure.MIN_DAYS_AFTER_FIRST_TWO_WAY_MESSAGE == 14
    )
    # even with the flag forced on in the table the stub never says eligible
    FeatureFlag.objects.create(key=gate.DISCLOSURE, enabled=True)
    selectors.invalidate()
    assert disclosure.get_eligibility().check(match, a, b).eligible is False


def test_counselling_and_due_diligence_raise_not_enabled():
    svc = counselling.get_service()
    with pytest.raises(gate.NotEnabled):
        svc.list_providers()
    with pytest.raises(gate.NotEnabled):
        svc.book(member_id=uuid.uuid4(), provider_id=uuid.uuid4(), starts_at=datetime.now(UTC))
    with pytest.raises(gate.NotEnabled):
        due_diligence.get_service().request_check(
            due_diligence.DueDiligenceRequest(uuid.uuid4(), uuid.uuid4(), "land_title")
        )


def test_no_models_tables_migrations_endpoints_or_apps():
    assert not [m for m in apps.get_models() if m.__module__.startswith("mc.phase5")]
    assert not [a for a in settings.INSTALLED_APPS if "phase5" in a]
    files = {p.name for p in PHASE5.rglob("*.py") if "tests" not in p.parts}
    assert files <= ALLOWED_FILES, files - ALLOWED_FILES
    assert not list(PHASE5.rglob("migrations")) and not list(PHASE5.rglob("urls.py"))
    assert not list(PHASE5.rglob("views.py")) and not list(PHASE5.rglob("tasks.py"))
    assert not list(PHASE5.rglob("consumers.py")) and not list(PHASE5.rglob("models.py"))
    assert sorted(
        p.name for p in PHASE5.iterdir() if p.is_dir() and p.name not in {"tests", "__pycache__"}
    ) == [
        "counselling",
        "disclosure",
        "duediligence",
    ]


def _all_patterns(resolver, prefix=""):
    for p in resolver.url_patterns:
        text = prefix + str(p.pattern)
        if hasattr(p, "url_patterns"):
            yield from _all_patterns(p, text)
        else:
            yield text


@pytest.mark.parametrize("conf", ["config.urls_api", "config.urls_admin", "config.urls_pay"])
def test_no_route_mentions_phase5_features(conf):
    routes = list(_all_patterns(get_resolver(conf)))
    assert routes
    bad = [
        r for r in routes if any(w in r for w in ("disclosure", "counsel", "diligence", "phase5"))
    ]
    assert bad == []


def test_probing_plausible_phase5_paths_finds_nothing():
    c = Client(headers={"host": "api.mc.test"})
    for path in (
        "disclosure",
        "counselling",
        "counselling/providers",
        "due-diligence",
        "me/disclosure",
    ):
        assert c.get(f"/api/v1/{path}").status_code in (401, 404)


def test_nothing_outside_phase5_imports_it():
    offenders = []
    for base in (ROOT, ROOT.parent / "config", ROOT.parent / "devtools"):
        for path in base.rglob("*.py"):
            if PHASE5 in path.parents or "migrations" in path.parts:
                continue
            tree = ast.parse(path.read_text())
            for node in ast.walk(tree):
                names = []
                if isinstance(node, ast.Import):
                    names = [a.name for a in node.names]
                elif isinstance(node, ast.ImportFrom):
                    names = [node.module or ""]
                    if node.module == "mc":
                        names += [f"mc.{a.name}" for a in node.names]
                if any(n == "mc.phase5" or n.startswith("mc.phase5.") for n in names):
                    offenders.append(str(path.relative_to(ROOT.parent)))
    assert offenders == []


def test_phase5_only_uses_public_interfaces_of_other_modules():
    """Mirror of the import-linter rule: no other module's models/api/tasks from the stubs, even in tests."""
    bad = []
    for path in PHASE5.rglob("*.py"):
        if "tests" in path.parts:
            continue
        for node in ast.walk(ast.parse(path.read_text())):
            mod = node.module if isinstance(node, ast.ImportFrom) else None
            internal = mod is not None and mod.rsplit(".", 1)[-1] in {
                "models", "api", "tasks", "admin_views",
            }  # fmt: skip
            if mod and mod.startswith("mc.") and not mod.startswith("mc.phase5") and internal:
                bad.append((str(path), mod))
    assert bad == []

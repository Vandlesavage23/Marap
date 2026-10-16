"""Guards the module-boundary setup itself (MC-022)."""

import tomllib
from pathlib import Path

BACKEND = Path(__file__).resolve().parent.parent
NOT_DOMAIN = {"common", "phase5", "__pycache__"}


def test_every_domain_module_is_covered_by_boundary_contracts():
    config = tomllib.loads((BACKEND / "pyproject.toml").read_text())
    contracts = config["tool"]["importlinter"]["contracts"]
    covered = set()
    for c in contracts:
        for m in c.get("forbidden_modules", []):
            covered.add(m.split(".")[1])
    modules = {
        p.name for p in (BACKEND / "mc").iterdir() if p.is_dir() and p.name not in NOT_DOMAIN
    }
    assert modules <= covered, f"add to importlinter contracts: {sorted(modules - covered)}"


def _contracts() -> list[dict]:
    return tomllib.loads((BACKEND / "pyproject.toml").read_text())["tool"]["importlinter"][
        "contracts"
    ]


def test_phase5_is_unreachable_and_may_only_use_public_module_interfaces():
    """Phase 5 stubs (Bible §18): nothing may import them, and they are a source in every internals contract."""
    unreachable = [c for c in _contracts() if c.get("forbidden_modules") == ["mc.phase5"]]
    assert len(unreachable) == 1
    sources = set(unreachable[0]["source_modules"])
    modules = {
        p.name for p in (BACKEND / "mc").iterdir() if p.is_dir() and p.name not in NOT_DOMAIN
    }
    assert {"config", "mc.common"} | {f"mc.{m}" for m in modules} <= sources
    internals = [
        c
        for c in _contracts()
        if c["name"].endswith("internals are private to " + c["name"].split()[0])
    ]
    assert len(internals) == len(modules)
    assert all("mc.phase5" in c["source_modules"] for c in internals)


def test_generator_output_is_in_sync_with_pyproject():
    """Someone added a module or phase5 package and forgot `uv run python scripts/gen_importlinter.py`."""
    import importlib.util

    spec = importlib.util.spec_from_file_location(
        "gen", BACKEND / "scripts" / "gen_importlinter.py"
    )
    assert spec and spec.loader
    gen = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(gen)
    text = (BACKEND / "pyproject.toml").read_text()
    mods = sorted(
        p.name for p in (BACKEND / "mc").iterdir() if p.is_dir() and p.name not in gen.NOT_DOMAIN
    )
    for m in mods:
        assert f'name = "{m} internals are private to {m}"' in text, m
    assert 'name = "phase5 is unreachable' in text

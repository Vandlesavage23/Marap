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

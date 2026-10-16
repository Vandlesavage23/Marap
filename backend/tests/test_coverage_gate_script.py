import importlib.util
import json
from pathlib import Path

BACKEND = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location(
    "gate", BACKEND / "scripts" / "check_module_coverage.py"
)
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)


def report(**modules):
    return {
        "files": {
            f"mc/{m}/services.py": {"summary": {"covered_lines": c, "num_statements": n}}
            for m, (c, n) in modules.items()
        }
    }


def test_module_of():
    assert gate.module_of("mc/billing/services.py") == "billing"
    assert gate.module_of("/abs/backend/mc/safety/api/views.py") == "safety"
    assert gate.module_of("config/settings/base.py") is None
    assert gate.module_of("mc/__init__.py") is None


def test_percentages_aggregate_statements_not_file_averages():
    r = report(billing=(90, 100), safety=(10, 10))
    r["files"]["mc/billing/tasks.py"] = {"summary": {"covered_lines": 0, "num_statements": 100}}
    pct = gate.module_percentages(r)
    assert pct["billing"] == 45.0 and pct["safety"] == 100.0 and pct["accounts"] == 0.0


def test_gate_passes_at_threshold_and_fails_below():
    full = dict.fromkeys(gate.GATED, (90, 100))
    assert gate.check(report(**full))[0] is True
    full["interests"] = (899, 1000)
    ok, lines = gate.check(report(**full))
    assert ok is False and any(line.startswith("FAIL") and "interests" in line for line in lines)


def test_a_gated_module_missing_from_the_report_fails():
    assert gate.check(report(billing=(100, 100)))[0] is False  # others have 0 statements -> 0%


def test_main_reads_the_json_file(tmp_path):
    p = tmp_path / "cov.json"
    p.write_text(json.dumps(report(**dict.fromkeys(gate.GATED, (95, 100)))))
    assert gate.main([str(p)]) == 0
    p.write_text(json.dumps(report(**dict.fromkeys(gate.GATED, (50, 100)))))
    assert gate.main([str(p)]) == 1
    assert gate.main([str(p), "--min", "40"]) == 0
    assert gate.main([str(tmp_path / "nope.json")]) == 2

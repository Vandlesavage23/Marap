"""Per-module coverage gate (Bible §13.3). Reads the JSON written by `coverage json` / `pytest --cov-report=json`
and fails if a gated module is below its threshold.

    uv run pytest --cov=mc --cov-report=json
    uv run python scripts/check_module_coverage.py [coverage.json] [--min 90]
"""

import json
import sys
from pathlib import Path

GATED = ("entitlements", "billing", "interests", "safety", "accounts")
DEFAULT_MIN = 90.0


def module_of(path: str) -> str | None:
    """`mc/billing/services.py` -> `billing`; anything outside mc/<module>/ -> None."""
    parts = Path(path).as_posix().split("/")
    if "mc" in parts:
        i = parts.index("mc")
        if len(parts) > i + 2:
            return parts[i + 1]
    return None


def module_percentages(report: dict, modules: tuple[str, ...] = GATED) -> dict[str, float]:
    covered = dict.fromkeys(modules, 0)
    total = dict.fromkeys(modules, 0)
    for path, data in report["files"].items():
        mod = module_of(path)
        if mod in total:
            summary = data["summary"]
            covered[mod] += summary["covered_lines"]
            total[mod] += summary["num_statements"]
    return {m: (100.0 * covered[m] / total[m]) if total[m] else 0.0 for m in modules}


def check(report: dict, *, minimum: float = DEFAULT_MIN) -> tuple[bool, list[str]]:
    lines, ok = [], True
    for mod, pct in module_percentages(report).items():
        passed = pct >= minimum
        ok &= passed
        lines.append(f"{'ok  ' if passed else 'FAIL'} mc/{mod:<13} {pct:6.2f}%  (min {minimum:g}%)")
    return ok, lines


def main(argv: list[str]) -> int:
    args = [a for a in argv if not a.startswith("--")]
    minimum = DEFAULT_MIN
    if "--min" in argv:
        minimum = float(argv[argv.index("--min") + 1])
        args = [a for a in args if a != argv[argv.index("--min") + 1]]
    path = Path(args[0] if args else "coverage.json")
    if not path.exists():
        print(f"{path} not found: run pytest with --cov-report=json first")
        return 2
    ok, lines = check(json.loads(path.read_text()), minimum=minimum)
    print("\n".join(lines))
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

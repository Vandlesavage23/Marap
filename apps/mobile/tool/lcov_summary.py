#!/usr/bin/env python3
"""Summarise an lcov.info: total and per top-level folder line coverage, generated files excluded.

    python3 tool/lcov_summary.py coverage/lcov.info [--min 0] [--markdown]

Counts only what lcov says (LF = lines found, LH = lines hit). It does not know about untested files that
Flutter did not instrument, so the number is a floor on "files that tests load", not a promise about the
whole codebase. Exit code 1 only when --min is given and the total is below it."""

import argparse
import sys
from collections import defaultdict

EXCLUDE_SUFFIXES = (".g.dart", ".freezed.dart")
EXCLUDE_PARTS = ("/l10n/gen/",)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("lcov")
    ap.add_argument("--min", type=float, default=0.0)
    ap.add_argument("--markdown", action="store_true")
    args = ap.parse_args()

    found: dict[str, int] = {}
    hit: dict[str, int] = {}
    current = None
    with open(args.lcov, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if line.startswith("SF:"):
                current = line[3:]
            elif line.startswith("LF:") and current:
                found[current] = int(line[3:])
            elif line.startswith("LH:") and current:
                hit[current] = int(line[3:])
            elif line == "end_of_record":
                current = None

    groups: dict[str, list[int]] = defaultdict(lambda: [0, 0])
    total_f = total_h = skipped = 0
    for path, lf in found.items():
        if path.endswith(EXCLUDE_SUFFIXES) or any(p in path for p in EXCLUDE_PARTS):
            skipped += 1
            continue
        lh = hit.get(path, 0)
        parts = path.split("/")
        depth = 4 if parts[:3] == ["lib", "src", "features"] else 3
        key = "/".join(parts[:depth]) if parts[0] == "lib" and len(parts) > depth else "/".join(parts[:-1]) or path
        groups[key][0] += lf
        groups[key][1] += lh
        total_f += lf
        total_h += lh

    def pct(h: int, f: int) -> float:
        return 100.0 * h / f if f else 0.0

    rows = sorted(groups.items())
    total = pct(total_h, total_f)
    if args.markdown:
        print("### Dart line coverage (generated files excluded)\n")
        print("| Folder | Lines hit / found | % |\n| --- | --- | --- |")
        for k, (f, h) in rows:
            print(f"| `{k}` | {h} / {f} | {pct(h, f):.1f} |")
        print(f"| **total** | **{total_h} / {total_f}** | **{total:.1f}** |")
        print(f"\n{len(found) - skipped} files instrumented, {skipped} generated files excluded.")
    else:
        for k, (f, h) in rows:
            print(f"{pct(h, f):6.1f}%  {h:6d}/{f:<6d}  {k}")
        print(f"{total:6.1f}%  {total_h:6d}/{total_f:<6d}  TOTAL ({skipped} generated files excluded)")
    return 1 if args.min and total < args.min else 0


if __name__ == "__main__":
    sys.exit(main())

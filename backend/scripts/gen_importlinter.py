"""Regenerate the module-boundary contracts in pyproject.toml from the modules present in mc/.

Run after adding a module:  uv run python scripts/gen_importlinter.py
"""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NOT_DOMAIN = {"common", "phase5", "__pycache__"}
# Phase 5 stubs (Bible §18) are interfaces only: they may call domain modules like any other module (so they are a
# *source* in every "internals are private" contract) but nothing may import them (see the extra contract below).
PHASE5 = "mc.phase5"
MARK = "# --- generated contracts (scripts/gen_importlinter.py) ---"


def contract(name: str, src: list[str], forb: list[str]) -> str:
    q = lambda xs: "[" + ", ".join(f'"{x}"' for x in xs) + "]"  # noqa: E731
    return (
        "[[tool.importlinter.contracts]]\n"
        f'name = "{name}"\ntype = "forbidden"\nsource_modules = {q(src)}\n'
        f"forbidden_modules = {q(forb)}\nallow_indirect_imports = true\n"
        'ignore_imports = ["mc.**.tests.** -> mc.**"]\n\n'
    )


def main() -> None:
    mods = sorted(
        p.name for p in (ROOT / "mc").iterdir() if p.is_dir() and p.name not in NOT_DOMAIN
    )
    out = [
        MARK + "\n\n",
        contract(
            "common is a leaf: it never imports domain modules",
            ["mc.common"],
            [f"mc.{m}" for m in mods],
        ),
    ]
    out.append(
        contract(
            "phase5 is unreachable: nothing imports the Phase 5 stubs",
            ["config", "mc.common", *[f"mc.{m}" for m in mods]],
            [PHASE5],
        )
    )
    for m in mods:
        others = [f"mc.{o}" for o in mods if o != m] + [PHASE5]
        if others:
            out.append(
                contract(
                    f"{m} internals are private to {m}",
                    others,
                    [f"mc.{m}.{part}" for part in ("models", "api", "tasks", "admin_views")],
                )
            )
    path = ROOT / "pyproject.toml"
    text = path.read_text()
    head = re.split(re.escape(MARK) + "|\\[\\[tool.importlinter.contracts\\]\\]", text, maxsplit=1)[
        0
    ].rstrip()
    path.write_text(head + "\n\n" + "".join(out).rstrip() + "\n")


if __name__ == "__main__":
    main()

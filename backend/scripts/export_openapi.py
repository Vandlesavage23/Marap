"""Write (or with --check, verify) the committed OpenAPI contract at docs/api/openapi.yaml.

uv run python scripts/export_openapi.py          # regenerate after changing an endpoint
uv run python scripts/export_openapi.py --check  # CI: exit 1 with a diff if the file is stale
"""

import difflib
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.test")


def main(argv: list[str]) -> int:
    import django

    django.setup()
    from mc.common import openapi_export

    fresh = openapi_export.render()
    path = openapi_export.COMMITTED
    if "--check" in argv:
        current = path.read_text() if path.exists() else ""
        if current == fresh:
            print(f"{path} is up to date")
            return 0
        diff = difflib.unified_diff(
            current.splitlines(), fresh.splitlines(), "committed", "generated", lineterm="", n=2
        )
        print("\n".join(list(diff)[:200]))
        print(f"\n{path} is stale: run `uv run python scripts/export_openapi.py` and commit it.")
        return 1
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(fresh)
    print(f"wrote {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

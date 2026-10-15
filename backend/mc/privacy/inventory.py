"""Data-inventory check (MC-116): every model field must be covered by a row in docs/privacy/data-inventory.csv.

Row key (first column) is `app.Model.fields` where `fields` is `*`, one field, `f1 / f2`, or `(f1/f2/f3)`.
Base fields (id, created_at, updated_at) are exempt. CI fails when a new field has no row."""

import csv
import re
from pathlib import Path

from django.apps import apps
from django.conf import settings

EXEMPT = {"id", "created_at", "updated_at"}
CSV_PATH = Path(settings.BASE_DIR).parent / "docs" / "privacy" / "data-inventory.csv"


def parse(path: Path = CSV_PATH) -> dict[str, set[str]]:
    covered: dict[str, set[str]] = {}
    with path.open() as f:
        for row in csv.reader(f):
            if not row or row[0] == "field":
                continue
            m = re.match(r"^([a-z_]+\.[A-Za-z]+)\.(.+)$", row[0].strip())
            if not m:
                continue
            fields = {x.strip(" ()") for x in re.split(r"[/,]", m.group(2)) if x.strip(" ()")}
            covered.setdefault(m.group(1), set()).update(fields)
    return covered


def missing(path: Path = CSV_PATH) -> list[str]:
    covered = parse(path)
    out = []
    for model in apps.get_models():
        if not model.__module__.startswith("mc."):
            continue
        key = f"{model._meta.app_label}.{model.__name__}"
        have = covered.get(key, set())
        if "*" in have:
            continue
        for field in model._meta.concrete_fields:
            if field.name in EXEMPT or field.name in have or field.attname in have:
                continue
            out.append(f"{key}.{field.name}")
    return sorted(out)

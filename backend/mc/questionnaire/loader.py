"""Idempotent upsert of the seeded question set. Used by the data migration and `seed_questions`."""

import json
from pathlib import Path
from typing import Any

FIXTURE = Path(__file__).parent / "fixtures" / "questions_v1.json"
FIELDS = (
    "version", "dimension", "type", "prompt", "options", "is_core", "is_special", "consent_kind",
    "allow_dealbreaker", "scoring_allowed", "scoring", "position",
)  # fmt: skip


def load(question_model: Any, path: Path = FIXTURE) -> int:
    data = json.loads(path.read_text())
    n = 0
    for q in data["questions"]:
        values = {f: q[f] for f in FIELDS}
        question_model.objects.update_or_create(key=q["key"], defaults={**values, "active": True})
        n += 1
    return n

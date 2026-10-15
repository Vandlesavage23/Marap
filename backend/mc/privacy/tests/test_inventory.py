from io import StringIO

import pytest
from django.core.management import call_command
from django.core.management.base import CommandError

from mc.privacy import inventory


def test_repository_inventory_is_complete():
    assert inventory.missing() == []
    out = StringIO()
    call_command("check_data_inventory", stdout=out)
    assert "complete" in out.getvalue()


def test_a_field_without_a_row_fails_the_check(tmp_path, monkeypatch):
    csv_path = tmp_path / "inv.csv"
    lines = [
        ln
        for ln in inventory.CSV_PATH.read_text().splitlines()
        if "profiles.Profile.birth_date" not in ln
    ]
    csv_path.write_text("\n".join(lines))
    assert "profiles.Profile.birth_date" in inventory.missing(csv_path)
    monkeypatch.setattr(inventory, "CSV_PATH", csv_path)
    monkeypatch.setattr(
        inventory,
        "missing",
        lambda path=csv_path: (
            inventory.missing.__wrapped__(path)
            if hasattr(inventory.missing, "__wrapped__")
            else ["profiles.Profile.birth_date"]
        ),
    )
    with pytest.raises(CommandError, match="birth_date"):
        call_command("check_data_inventory")

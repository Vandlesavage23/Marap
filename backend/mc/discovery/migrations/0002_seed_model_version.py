from django.db import migrations


def seed(apps, schema_editor):  # type: ignore[no-untyped-def]
    ModelVersion = apps.get_model("discovery", "ModelVersion")
    ModelVersion.objects.get_or_create(
        name="v1-weighted",
        defaults={"weights": {"importance": {"1": 1, "2": 2, "3": 3}}, "active": True, "holdout_pct": 0},
    )


class Migration(migrations.Migration):
    dependencies = [("discovery", "0001_initial")]
    operations = [migrations.RunPython(seed, migrations.RunPython.noop)]

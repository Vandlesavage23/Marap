from django.db import migrations

from mc.questionnaire.loader import load


def seed(apps, schema_editor):  # type: ignore[no-untyped-def]
    load(apps.get_model("questionnaire", "Question"))


class Migration(migrations.Migration):
    dependencies = [("questionnaire", "0001_initial")]
    operations = [migrations.RunPython(seed, migrations.RunPython.noop)]

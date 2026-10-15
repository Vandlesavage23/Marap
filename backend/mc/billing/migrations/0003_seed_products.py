from django.db import migrations

# PLACEHOLDER prices/ids (planning assumptions, Bible §11.2) — product/finance to confirm before launch.
PRODUCTS = [
    ("membership_1m", 30, 20000, "ug.marriageconnect.membership_1m", "membership_1m", True),
    ("membership_3m", 90, 50000, "ug.marriageconnect.membership_3m", "membership_3m", True),
    ("membership_6m", 180, 90000, "", "", True),  # web prepaid only (store products are 1m/3m)
]


def seed(apps, schema_editor):  # type: ignore[no-untyped-def]
    Product = apps.get_model("billing", "Product")
    for code, days, price, apple, google, web in PRODUCTS:
        Product.objects.get_or_create(
            code=code,
            defaults={"duration_days": days, "price_minor": price, "currency": "UGX", "apple_product_id": apple, "google_product_id": google, "web_enabled": web, "active": True},
        )


class Migration(migrations.Migration):
    dependencies = [("billing", "0002_payment_event_immutable")]
    operations = [migrations.RunPython(seed, migrations.RunPython.noop)]

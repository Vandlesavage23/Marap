import uuid

from .models import Product, Purchase


def active_products(*, platform: str) -> list[Product]:
    qs = Product.objects.filter(active=True).order_by("duration_days")
    if platform == "ios":
        return list(qs.exclude(apple_product_id=""))
    if platform == "android":
        return list(qs.exclude(google_product_id=""))
    if platform == "web":
        return list(qs.filter(web_enabled=True))
    return []


def purchase_history(account_id: uuid.UUID):  # type: ignore[no-untyped-def]
    return Purchase.objects.filter(account_id=account_id).select_related("product").order_by("-id")


def get_product(code: str) -> Product | None:
    return Product.objects.filter(code=code, active=True).first()

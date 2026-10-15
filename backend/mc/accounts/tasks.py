import uuid

from celery import shared_task

from .providers.sms import get_sms_provider


@shared_task(queue="notify", autoretry_for=(Exception,), retry_backoff=True, max_retries=3)
def send_new_device_alert(account_id: str, platform: str) -> None:
    from .models import Account  # id only crosses the broker; the phone is looked up here

    account = Account.objects.filter(id=uuid.UUID(account_id)).only("phone_e164").first()
    if account is None:
        return
    label = {"android": "an Android", "ios": "an iPhone"}.get(platform, "a new")
    get_sms_provider().send(
        to_e164=account.phone_e164,
        body=f"Marriage Connect: new sign-in on {label} device. "
        "If this wasn't you, sign out other devices in the app.",
    )

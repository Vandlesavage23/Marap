import uuid

from celery import shared_task

from mc.accounts import selectors as account_selectors
from mc.accounts import services as account_services

from . import services
from .providers.push import InvalidToken, PushMessage, get_push_provider


@shared_task(queue="notify", autoretry_for=(Exception,), retry_backoff=True, max_retries=4)
def send_push(account_id: str, type: str, data: dict[str, str]) -> int:
    """Deliver to every device with a token; prune tokens the provider says are invalid. Returns sent count."""
    provider = get_push_provider()
    message = PushMessage(type=type, data=data, body=services.push_body(type))
    sent = 0
    for platform, token in account_selectors.push_targets(uuid.UUID(account_id)):
        try:
            provider.send(platform=platform, token=token, message=message)
            sent += 1
        except InvalidToken:
            account_services.clear_push_token(platform=platform, token=token)
    return sent

from mc.accounts.events import ConsentChanged
from mc.common.events import subscribe

from . import services


@subscribe(ConsentChanged)
def on_consent_changed(event: ConsentChanged) -> None:
    if not event.granted:
        services.delete_special_answers(account_id=event.account_id, consent_kind=event.kind)

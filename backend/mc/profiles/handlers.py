from mc.accounts.events import ConsentChanged
from mc.common.events import subscribe

from . import services


@subscribe(ConsentChanged)
def on_consent_changed(event: ConsentChanged) -> None:
    if not event.granted:
        services.clear_special_data(account_id=event.account_id, kind=event.kind)

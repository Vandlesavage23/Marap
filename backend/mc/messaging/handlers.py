from mc.common.events import subscribe
from mc.matches.events import MatchCreated

from . import services


@subscribe(MatchCreated)
def on_match_created(event: MatchCreated) -> None:
    services.create_system_message(match_id=event.match_id, code="match_created")

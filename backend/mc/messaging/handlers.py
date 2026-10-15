from mc.common.events import subscribe
from mc.matches.events import MatchCreated

from . import services


@subscribe(MatchCreated)
def on_match_created(event: MatchCreated) -> None:
    services.create_system_message(match_id=event.match_id, code="match_created")


# ---- realtime fan-out (after commit) -------------------------------------------------------------
from mc.accounts import selectors as _account_selectors  # noqa: E402
from mc.matches import selectors as _match_selectors  # noqa: E402
from mc.matches.events import MatchEnded  # noqa: E402
from mc.profiles import selectors as _profile_selectors  # noqa: E402

from . import realtime, selectors  # noqa: E402
from .events import MessageCreated, MessageRead  # noqa: E402


@subscribe(MessageCreated)
def push_message_to_sockets(event: MessageCreated) -> None:
    msg = selectors.get_message(event.message_id)
    if msg is None:
        return
    match = msg.match
    targets = [event.recipient_id] if event.recipient_id else [match.user_a_id, match.user_b_id]
    for account_id in targets:
        viewer = _account_selectors.get_account(account_id)
        if viewer is not None:
            realtime.send_to_account(
                account_id,
                {"type": "chat.message", "message": _plain(selectors.message_payload(msg, viewer))},
            )


@subscribe(MessageRead)
def push_read_receipt(event: MessageRead) -> None:
    match = _match_selectors.get_match(event.match_id)
    if match is None:
        return
    other = _match_selectors.other_member(match, event.reader_id)
    reader_profile = _profile_selectors.profile_id_for_account(event.reader_id)
    realtime.send_to_account(
        other,
        {
            "type": "chat.read",
            "data": {
                "match_id": str(event.match_id),
                "reader_id": str(reader_profile),
                "up_to_message_id": str(event.up_to_message_id),
            },
        },
    )


@subscribe(MatchEnded)
def push_match_ended(event: MatchEnded) -> None:
    """No reason is given to the clients (Bible §9.1)."""
    for account_id in (event.user_a, event.user_b):
        realtime.send_to_account(
            account_id, {"type": "chat.match_ended", "match_id": str(event.match_id)}
        )


def _plain(body: dict) -> dict:
    import json

    from rest_framework.utils.encoders import JSONEncoder

    return json.loads(json.dumps(body, cls=JSONEncoder))

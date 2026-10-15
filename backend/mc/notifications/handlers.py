from mc.accounts.events import NewDeviceSignIn
from mc.common import presence
from mc.common.events import subscribe
from mc.entitlements.events import TrialReminderDue
from mc.interests.events import InterestSent
from mc.matches.events import MatchCreated
from mc.messaging.events import MessageCreated

from . import services


@subscribe(InterestSent)
def on_interest_sent(e: InterestSent) -> None:
    services.notify(
        account_id=e.recipient_id,
        type="interest_received",
        payload={"interest_id": e.interest_id},
        counterpart_id=e.sender_id,
    )


@subscribe(MatchCreated)
def on_match_created(e: MatchCreated) -> None:
    for me, other in ((e.user_a, e.user_b), (e.user_b, e.user_a)):
        services.notify(
            account_id=me,
            type="match_created",
            payload={"match_id": e.match_id},
            counterpart_id=other,
        )


@subscribe(MessageCreated)
def on_message_created(e: MessageCreated) -> None:
    if e.kind == "system" or e.recipient_id is None or presence.is_online(e.recipient_id):
        return  # recipients with a live socket get the frame; no push
    services.notify(
        account_id=e.recipient_id,
        type="new_message",
        payload={"match_id": e.match_id},
        counterpart_id=e.sender_id,
        debounce_key=f"{e.recipient_id}:{e.match_id}",
    )


@subscribe(TrialReminderDue)
def on_trial_reminder(e: TrialReminderDue) -> None:
    services.notify(
        account_id=e.account_id,
        type="trial_ending_soon" if e.kind == "ending_soon" else "trial_ended",
    )


@subscribe(NewDeviceSignIn)
def on_new_device(e: NewDeviceSignIn) -> None:
    services.notify(account_id=e.account_id, type="new_device", payload={"device_id": e.device_id})

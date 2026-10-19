from mc.accounts.events import ConsentChanged
from mc.common.events import subscribe
from mc.questionnaire.events import AnswersSaved
from mc.verification.events import AccountVerified

from . import services


@subscribe(ConsentChanged)
def on_consent_changed(event: ConsentChanged) -> None:
    if not event.granted:
        services.clear_special_data(account_id=event.account_id, kind=event.kind)


@subscribe(AnswersSaved)
def on_answers_saved(event: AnswersSaved) -> None:
    from .models import Profile

    profile = Profile.objects.filter(account_id=event.account_id).first()
    if profile:
        services.refresh(profile)


@subscribe(AccountVerified)
def on_account_verified(event: AccountVerified) -> None:
    services.adopt_verified_birth_date(account_id=event.account_id)

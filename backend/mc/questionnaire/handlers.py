from django.db import transaction
from django.db.models.signals import post_delete, post_save
from django.dispatch import receiver

from mc.accounts.events import ConsentChanged
from mc.common.events import subscribe

from . import scoring_cache, services
from .models import Answer


@subscribe(ConsentChanged)
def on_consent_changed(event: ConsentChanged) -> None:
    if not event.granted:
        services.delete_special_answers(account_id=event.account_id, consent_kind=event.kind)


def _invalidate_scoring_cache(account_id) -> None:  # type: ignore[no-untyped-def]
    """Bump now (visible to the very next read) and again after commit (closes the read-during-write
    race). Fires for saves, deletes, consent-withdrawal deletes and the account-deletion cascade."""
    scoring_cache.bump([account_id])
    transaction.on_commit(lambda: scoring_cache.bump([account_id]))


@receiver(post_save, sender=Answer, dispatch_uid="questionnaire.answer_saved_cache")
def on_answer_saved(sender, instance, **kwargs) -> None:  # type: ignore[no-untyped-def]
    _invalidate_scoring_cache(instance.account_id)


@receiver(post_delete, sender=Answer, dispatch_uid="questionnaire.answer_deleted_cache")
def on_answer_deleted(sender, instance, **kwargs) -> None:  # type: ignore[no-untyped-def]
    _invalidate_scoring_cache(instance.account_id)

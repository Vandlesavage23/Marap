from .models import Account, Session


def can_manage_session(account: Account, session: Session) -> bool:
    return session.account_id == account.id

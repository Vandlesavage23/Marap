import uuid

from mc.accounts.tests.helpers import bearer
from mc.interests.tests.helpers import accept, member, pair, send
from mc.verification.tests.helpers import J


def matched():
    m, f = pair()
    iid = send(m[0], m[1], f[3]).json()["id"]
    mid = accept(f[0], f[1], iid).json()["match_id"]
    return m, f, mid


def say(who, mid, text="Hello there", cid=None, kind="text", **extra):
    body = {"client_msg_id": cid or str(uuid.uuid4()), "kind": kind, **extra}
    if kind == "text":
        body["body"] = text
    return who[0].post(f"/api/v1/matches/{mid}/messages", body, **bearer(who[1]), **J)


def history(who, mid, **params):
    qs = "&".join(f"{k}={v}" for k, v in params.items())
    return who[0].get(f"/api/v1/matches/{mid}/messages?{qs}", **bearer(who[1]))


__all__ = ["accept", "history", "matched", "member", "pair", "say", "send"]

from mc.accounts.models import Account
from mc.accounts.tests.helpers import bearer
from mc.verification.tests.helpers import J, callback, job_id_of, new_user, result, start


def verified_client(phone="+256772000001", id_number=None, **result_kw):
    c, r = new_user(phone)
    callback(
        c, result(job_id_of(start(c, r)), id_number=id_number or f"ID{phone[-6:]}", **result_kw)
    )
    return c, r, Account.objects.get(phone_e164=phone)


def patch(c, r, **body):
    return c.patch("/api/v1/me/profile", body, **bearer(r), **J)


def consent(c, r, *kinds, granted=True):
    items = [{"kind": k, "version": "2026-01", "granted": granted} for k in kinds]
    return c.post("/api/v1/me/consents", {"consents": items}, **bearer(r), **J)


BASIC = {
    "display_name": "Amani",
    "gender": "female",
    "district": "Wakiso",
    "intention": "marriage_soon",
    "marriage_timeline": "1_2y",
    "marital_status": "never_married",
}

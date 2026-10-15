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


def ready_media(owner, moderation="approved", face_count=1):
    import uuid

    from mc.media.models import MediaObject

    mid = uuid.uuid4()
    return MediaObject.objects.create(
        id=mid, owner=owner, purpose="profile_photo", declared_mime="image/jpeg", declared_bytes=1000,
        upload_key=f"uploads/{mid}", storage_key=f"media/{mid}.webp",
        mime="image/webp", bytes=900, width=800, height=1000, status="ready",
        moderation=moderation, face_count=face_count,
    )  # fmt: skip


def add_photo(c, r, media):
    import uuid

    return c.post(
        "/api/v1/me/photos",
        {"media_id": str(media.id)},
        **bearer(r),
        HTTP_IDEMPOTENCY_KEY=uuid.uuid4().hex,
        **J,
    )


def make_ready_member(c, r, acct, *, gender="female", name="Amani", extra=None):
    """Drive a verified user all the way to a go-live-ready profile through the real endpoints."""
    import uuid

    from mc.profiles import services
    from mc.questionnaire.tests.test_questionnaire import core_answers

    patch(c, r, **{**BASIC, "gender": gender, "display_name": name, **(extra or {})})
    for _ in range(2):
        add_photo(c, r, ready_media(acct))
    desc = (
        "I am a teacher who loves gardening, cooking for my family on Sundays and long walks. I am "
        "looking for a kind, honest partner who values faith, family and hard work, ready to build a home."
    )
    c.post(
        "/api/v1/me/descriptions",
        {"text": desc},
        **bearer(r),
        HTTP_IDEMPOTENCY_KEY=uuid.uuid4().hex,
        **J,
    )
    c.put("/api/v1/me/answers", {"answers": core_answers()}, **bearer(r), **J)
    return services

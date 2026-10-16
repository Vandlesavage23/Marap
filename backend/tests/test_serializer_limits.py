"""What the API advertises (serializer limits, which drive the OpenAPI schema) must equal what the services enforce.
Each case checks the boundary on both sides so a change to one without the other fails here."""

import uuid

import pytest
from django.conf import settings

from devtools.factories import create_member
from mc.beta.api.serializers import FeedbackSerializer
from mc.common.errors import DomainError, NotFound, ValidationFailed
from mc.messaging.api.serializers import SendMessageSerializer
from mc.profiles.api.serializers import (
    DescriptionSerializer,
    PhotoOrderSerializer,
    ProfileUpdateSerializer,
)
from mc.safety.api.serializers import AppealSerializer as SafetyAppealSerializer
from mc.safety.api.serializers import ReportSerializer
from mc.verification.api.serializers import AppealSerializer as VerificationAppealSerializer

pytestmark = pytest.mark.django_db


def ok(serializer_cls, **data) -> bool:
    return serializer_cls(data=data).is_valid()


def service_accepts_length(call, *, expect_after: type[DomainError]) -> bool:
    """True if the service gets past its length check (it then fails later for an unrelated reason)."""
    try:
        call()
    except ValidationFailed:
        return False
    except expect_after:
        return True
    return True


# ---------------------------------------------------------------- appeals: 10-1,000
@pytest.mark.parametrize("n,valid", [(9, False), (10, True), (1000, True), (1001, False)])
def test_verification_appeal_message_limits_match_the_service(n, valid):
    from mc.verification import review

    msg = "a" * n
    assert ok(VerificationAppealSerializer, message=msg) is valid
    acct = create_member()
    assert (
        service_accepts_length(
            lambda: review.open_appeal(account=acct, attempt_id=None, message=msg),
            expect_after=NotFound,
        )
        is valid
    )


@pytest.mark.parametrize("n,valid", [(9, False), (10, True), (1000, True), (1001, False)])
def test_safety_appeal_message_limits_match_the_service(n, valid):
    from mc.safety import enforcement

    msg = "b" * n
    assert ok(SafetyAppealSerializer, action_id=str(uuid.uuid4()), message=msg) is valid
    acct = create_member()
    assert (
        service_accepts_length(
            lambda: enforcement.open_appeal(account=acct, action_id=uuid.uuid4(), message=msg),
            expect_after=NotFound,
        )
        is valid
    )


def test_appeal_whitespace_padding_does_not_count_on_either_side():
    padded = "   short   "  # 5 characters once trimmed
    assert ok(VerificationAppealSerializer, message=padded) is False
    assert ok(SafetyAppealSerializer, action_id=str(uuid.uuid4()), message=padded) is False


# ---------------------------------------------------------------- report note: max 1,000
@pytest.mark.parametrize("n,valid", [(0, True), (1000, True), (1001, False)])
def test_report_text_limit_matches_the_service(n, valid):
    from mc.safety import reports

    base = {"profile_id": str(uuid.uuid4()), "category": "spam", "context_type": "profile"}
    assert ok(ReportSerializer, **base, text="c" * n) is valid
    reporter = create_member()
    assert (
        service_accepts_length(
            lambda: reports.report(
                reporter=reporter,
                subject_profile_id=uuid.uuid4(),
                category="spam",
                context_type="profile",
                context_id=None,
                text="c" * n,
                idempotency_key=uuid.uuid4().hex,
            ),
            expect_after=NotFound,
        )
        is valid
    )


# ---------------------------------------------------------------- display name: 2-30
@pytest.mark.parametrize(
    "name,valid", [("A", False), ("Ab", True), ("a" * 30, True), ("a" * 31, False)]
)
def test_display_name_limits_match_the_name_rules(name, valid):
    from mc.profiles.names import normalise_display_name

    assert ok(ProfileUpdateSerializer, display_name=name) is valid
    try:
        normalise_display_name(name)
        service_ok = True
    except ValidationFailed:
        service_ok = False
    assert service_ok is valid


def test_display_name_column_fits_the_advertised_maximum():
    from mc.profiles.models import Profile

    assert Profile._meta.get_field("display_name").max_length == 30
    field = ProfileUpdateSerializer().fields["display_name"]
    assert (field.min_length, field.max_length) == (2, 30)


# ---------------------------------------------------------------- description: DESCRIPTION_MIN..MAX
def test_description_limits_come_from_the_same_settings_as_the_service():
    from mc.profiles import services

    lo, hi = settings.DESCRIPTION_MIN, settings.DESCRIPTION_MAX
    acct = create_member()
    for n, valid in ((lo - 1, False), (lo, True), (hi, True), (hi + 1, False)):
        text = "x" * n
        assert ok(DescriptionSerializer, text=text) is valid, n
        try:
            services.submit_description(account=acct, text=text)
            service_ok = True
        except ValidationFailed:
            service_ok = False
        except DomainError:
            service_ok = True  # screened/rejected: it got past the length check
        assert service_ok is valid, n


def test_description_serializer_trims_like_the_service():
    lo = settings.DESCRIPTION_MIN
    assert ok(DescriptionSerializer, text="  " + "y" * lo + "  ") is True
    assert ok(DescriptionSerializer, text="  " + "y" * (lo - 1) + "  ") is False


# ---------------------------------------------------------------- chat message: MESSAGE_MAX_CHARS
def test_message_body_limit_matches_the_service(settings):
    from mc.messaging import services
    from mc.messaging.tests.helpers import matched

    hi = settings.MESSAGE_MAX_CHARS
    base = {"client_msg_id": str(uuid.uuid4()), "kind": "text"}
    assert ok(SendMessageSerializer, **base, body="m" * hi) is True
    assert ok(SendMessageSerializer, **base, body="m" * (hi + 1)) is False
    m, f, mid = matched()
    with pytest.raises(ValidationFailed):
        services.send_message(
            sender=m[2], match_id=uuid.UUID(mid), client_msg_id=uuid.uuid4(), kind="text", body="m" * (hi + 1), media_id=None
        )  # fmt: skip
    msg, created = services.send_message(
        sender=m[2], match_id=uuid.UUID(mid), client_msg_id=uuid.uuid4(), kind="text", body="m" * hi, media_id=None
    )  # fmt: skip
    assert created and len(msg.body) == hi


# ---------------------------------------------------------------- beta feedback: 3-2,000
@pytest.mark.parametrize("n,valid", [(2, False), (3, True), (2000, True), (2001, False)])
def test_feedback_limits_match_the_service(n, valid):
    from mc.beta import services

    assert ok(FeedbackSerializer, message="f" * n) is valid
    acct = create_member()
    try:
        services.submit_feedback(account_id=acct.id, message="f" * n)
        service_ok = True
    except ValidationFailed:
        service_ok = False
    assert service_ok is valid


# ---------------------------------------------------------------- photo order: PHOTOS_MAX
def test_photo_order_limit_matches_the_photo_cap(settings):
    n = settings.PHOTOS_MAX
    assert ok(PhotoOrderSerializer, ids=[str(uuid.uuid4()) for _ in range(n)]) is True
    assert ok(PhotoOrderSerializer, ids=[str(uuid.uuid4()) for _ in range(n + 1)]) is False

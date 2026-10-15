"""Product configuration (Bible §17). `(A)` assumptions and PENDING OD-xx defaults live here,
env-overridable, so they can change without code changes. Never hard-code these deep in logic."""

import os


def _int(name: str, default: int) -> int:
    return int(os.environ.get(name, default))


def _float(name: str, default: float) -> float:
    return float(os.environ.get(name, default))


def _bool(name: str, default: bool) -> bool:
    return os.environ.get(name, str(default)).lower() in {"1", "true", "yes", "on"}


TRIAL_DURATION_HOURS = _int("TRIAL_DURATION_HOURS", 24)  # CONF-003
TRIAL_START_MODE = os.environ.get(
    "TRIAL_START_MODE", "explicit_after_verification"
)  # PENDING OD-02
INTEREST_DAILY_LIMIT_TRIAL = _int("INTEREST_DAILY_LIMIT_TRIAL", 20)
INTEREST_DAILY_LIMIT_MEMBER = _int("INTEREST_DAILY_LIMIT_MEMBER", 30)
INTEREST_EXPIRY_DAYS = _int("INTEREST_EXPIRY_DAYS", 30)
INTEREST_RESEND_COOLDOWN_DAYS = _int("INTEREST_RESEND_COOLDOWN_DAYS", 90)
NONMEMBER_CAN_ACCEPT_INTEREST = _bool("NONMEMBER_CAN_ACCEPT_INTEREST", True)  # PENDING OD-11
MARRIED_PROFILES_ENABLED = _bool("MARRIED_PROFILES_ENABLED", True)  # PENDING OD-03
MARRIED_VISIBILITY_DEFAULT = _bool("MARRIED_VISIBILITY_DEFAULT", False)  # PENDING OD-03
PHOTO_UNLOCK_MIN_MESSAGES = _int("PHOTO_UNLOCK_MIN_MESSAGES", 10)
CONTACT_BLOCK_HOURS = _int("CONTACT_BLOCK_HOURS", 72)
EXPOSURE_DAILY_CAP = _int("EXPOSURE_DAILY_CAP", 150)
NEW_PROFILE_BOOST = _float("NEW_PROFILE_BOOST", 0.05)
NEW_PROFILE_BOOST_DAYS = _int("NEW_PROFILE_BOOST_DAYS", 7)
REPEAT_HIDE_DAYS = _int("REPEAT_HIDE_DAYS", 30)
DESCRIPTION_MIN = _int("DESCRIPTION_MIN", 150)
DESCRIPTION_MAX = _int("DESCRIPTION_MAX", 1000)
DELETION_GRACE_DAYS = _int("DELETION_GRACE_DAYS", 30)
VERIFICATION_AUTO_ATTEMPTS_PER_DAY = _int("VERIFICATION_AUTO_ATTEMPTS_PER_DAY", 3)
TRIBE_PREFERENCE_ENABLED = _bool("TRIBE_PREFERENCE_ENABLED", False)  # PENDING OD-05
WEB_CHECKOUT_ENABLED = _bool("WEB_CHECKOUT_ENABLED", True)  # PENDING OD-01

# Auth / OTP (Bible §7.1, §10.1, §12.1) — (A)
ACCESS_TOKEN_MINUTES = _int("ACCESS_TOKEN_MINUTES", 15)
REFRESH_TOKEN_DAYS = _int("REFRESH_TOKEN_DAYS", 30)
OTP_TTL_MINUTES = _int("OTP_TTL_MINUTES", 10)
OTP_MAX_VERIFY_ATTEMPTS = _int("OTP_MAX_VERIFY_ATTEMPTS", 5)
OTP_SENDS_PER_PHONE_PER_HOUR = _int("OTP_SENDS_PER_PHONE_PER_HOUR", 5)
OTP_SENDS_PER_IP_PER_HOUR = _int("OTP_SENDS_PER_IP_PER_HOUR", 20)

IDEMPOTENCY_TTL_SECONDS = _int("IDEMPOTENCY_TTL_SECONDS", 24 * 3600)

FEATURE_FLAGS_DEFAULT = {
    "phase5_disclosure": False,
    "phase5_counselling": False,
    "phase5_due_diligence": False,
    "voice_notes": True,
    "data_saver_default_on_cellular": True,
}

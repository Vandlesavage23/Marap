"""Plain constants other modules may import without touching `models`."""

PENDING_VERIFICATION = "pending_verification"
ACTIVE = "active"
SUSPENDED = "suspended"
DEACTIVATED = "deactivated"
DELETED = "deleted"

# Privacy-safe client funnel steps accepted by POST /events (docs/design/user-flow-v2.md §6). Order = funnel order.
FUNNEL_STEPS = (
    "welcome_seen",
    "otp_sent",
    "otp_verified",
    "about_done",
    "first_card_seen",
    "profile_opened",
    "verify_started",
    "verify_passed",
    "golive_done",
    "first_interest",
    "paywall_seen",
    "trial_started",
)

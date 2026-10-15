"""Notification types. Push bodies are GENERIC by design: never names, message text or descriptions."""

CATALOG: dict[str, dict[str, object]] = {
    "interest_received": {"inbox": True, "body": "Someone is interested in you"},
    "match_created": {"inbox": True, "body": "You have a new match"},
    "new_message": {"inbox": False, "body": "You have a new message"},
    "trial_ending_soon": {"inbox": True, "body": "Your free trial ends soon"},
    "trial_ended": {"inbox": True, "body": "Your free trial has ended"},
    "warning": {"inbox": True, "body": "Please review our community guidelines"},
    "appeal_decided": {"inbox": True, "body": "Your appeal has been reviewed"},
    "new_device": {"inbox": True, "body": "New sign-in on your account"},
}

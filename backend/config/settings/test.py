from .base import *
from .product import *

MC_DOMAIN = "mc.test"
ALLOWED_HOSTS = [".mc.test"]
HOST_URLCONFS = {
    "api.mc.test": "config.urls_api",
    "admin.mc.test": "config.urls_admin",
    "pay.mc.test": "config.urls_pay",
}
SECRET_KEY = "test-only-secret"
OPENAPI_ENABLED = True
REDIS_URL = env("TEST_REDIS_URL", "redis://localhost:6379/15")
CHANNEL_LAYERS = {"default": {"BACKEND": "channels.layers.InMemoryChannelLayer"}}
CELERY_TASK_ALWAYS_EAGER = True
CELERY_TASK_EAGER_PROPAGATES = False
CELERY_TASK_ANNOTATIONS = {
    "*": {"retry_backoff": False, "retry_jitter": False, "default_retry_delay": 0}
}
PASSWORD_HASHERS = ["django.contrib.auth.hashers.MD5PasswordHasher"]

from mc.common.crypto import make_dev_keyring

MC_DATA_KEYS = make_dev_keyring(SECRET_KEY, ["k1", "k2"])
MC_DATA_KEY_CURRENT = "k1"
MC_PEPPERS = {
    p: f"dev-pepper-{p}" for p in ("id_number", "phone", "ip", "account", "otp", "identity")
}

from mc.common.crypto import dev_ed25519_pems

MC_JWT_PRIVATE_KEY_PEM, MC_JWT_PUBLIC_KEY_PEM = dev_ed25519_pems(SECRET_KEY)

AWS_ACCESS_KEY_ID = "testing"
AWS_SECRET_ACCESS_KEY = "testing"
AWS_S3_ENDPOINT_URL = ""

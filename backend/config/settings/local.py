from .base import *
from .product import *

DEBUG = True
OPENAPI_ENABLED = True

from mc.common.crypto import make_dev_keyring

MC_DATA_KEYS = make_dev_keyring(SECRET_KEY, ["k1", "k2"])
MC_DATA_KEY_CURRENT = "k1"
MC_PEPPERS = {
    p: f"dev-pepper-{p}" for p in ("id_number", "phone", "ip", "account", "otp", "identity")
}

from mc.common.crypto import dev_ed25519_pems

MC_JWT_PRIVATE_KEY_PEM, MC_JWT_PUBLIC_KEY_PEM = dev_ed25519_pems(SECRET_KEY)

INSTALLED_APPS += ["devtools"]  # dev-only management commands (seed_demo, bench_hard_filter)

# Local development: print OTP SMS to the server terminal (see mc.accounts.providers.sms.ConsoleSms).
SMS_PROVIDER = "mc.accounts.providers.sms.ConsoleSms"

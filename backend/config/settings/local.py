from .base import *
from .product import *

DEBUG = True
OPENAPI_ENABLED = True

from mc.common.crypto import make_dev_keyring

MC_DATA_KEYS = make_dev_keyring(SECRET_KEY, ["k1", "k2"])
MC_DATA_KEY_CURRENT = "k1"
MC_PEPPERS = {p: f"dev-pepper-{p}" for p in ("id_number", "phone", "ip", "account")}

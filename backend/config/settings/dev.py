from .base import *
from .product import *

OPENAPI_ENABLED = True
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
SECURE_SSL_REDIRECT = False  # TLS terminates at the ALB; health probes use plain HTTP
SECURE_HSTS_SECONDS = 31536000
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
INSTALLED_APPS += ["devtools"]  # dev-only management commands (seed_demo, bench_hard_filter)

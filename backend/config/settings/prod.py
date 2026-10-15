from .base import *
from .product import *

OPENAPI_ENABLED = False
SECRET_KEY = env("DJANGO_SECRET_KEY")  # required in prod
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
SECURE_SSL_REDIRECT = False  # TLS terminates at the ALB; health probes use plain HTTP
SECURE_HSTS_SECONDS = 31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True

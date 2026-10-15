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

SMS_PROVIDER = env("SMS_PROVIDER")  # required: never the fake in prod
MC_TRUSTED_PROXY_COUNT = int(env("MC_TRUSTED_PROXY_COUNT", "1"))
IDENTITY_PROVIDER = env("IDENTITY_PROVIDER")  # required: never the fake in prod
MALWARE_SCANNER = env("MALWARE_SCANNER")  # required: never the fake in prod
IMAGE_MODERATION_PROVIDER = env("IMAGE_MODERATION_PROVIDER")
PUSH_PROVIDER = env("PUSH_PROVIDER")  # required: never the fake in prod
PAYMENT_GATEWAY = env("PAYMENT_GATEWAY")  # required: never the fake in prod

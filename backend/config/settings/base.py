"""Base settings. All values come from the environment; secrets never live in the repo."""

import os
from pathlib import Path
from urllib.parse import unquote, urlparse

BASE_DIR = Path(__file__).resolve().parent.parent.parent


def env(name: str, default: str | None = None) -> str:
    value = os.environ.get(name, default)
    if value is None:
        raise RuntimeError(f"Missing required environment variable {name}")
    return value


def env_bool(name: str, default: bool = False) -> bool:
    return os.environ.get(name, str(default)).lower() in {"1", "true", "yes", "on"}


def database_from_url(url: str) -> dict[str, object]:
    parsed = urlparse(url)
    return {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": parsed.path.lstrip("/"),
        "USER": unquote(parsed.username or ""),
        "PASSWORD": unquote(parsed.password or ""),
        "HOST": parsed.hostname or "",
        "PORT": str(parsed.port or ""),
        "CONN_MAX_AGE": int(env("DB_CONN_MAX_AGE", "60")),
        "ATOMIC_REQUESTS": False,
    }


SECRET_KEY = env("DJANGO_SECRET_KEY", "insecure-local-only")
DEBUG = False

# Host routing (Bible §2.2): api.<domain>, admin.<domain>, pay.<domain>.
MC_DOMAIN = env("MC_DOMAIN", "localtest.me")
ALLOWED_HOSTS = [f".{MC_DOMAIN}", *filter(None, env("MC_EXTRA_ALLOWED_HOSTS", "").split(","))]
HOST_URLCONFS = {
    f"api.{MC_DOMAIN}": "config.urls_api",
    f"admin.{MC_DOMAIN}": "config.urls_admin",
    f"pay.{MC_DOMAIN}": "config.urls_pay",
}
ROOT_URLCONF = "config.urls_api"

INSTALLED_APPS = [
    "django.contrib.contenttypes",
    "django.contrib.postgres",
    "rest_framework",
    "drf_spectacular",
    "channels",
    "mc.common",
    "mc.audit",
]

MIDDLEWARE = [
    "mc.common.hosts.HostRoutingMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "django.middleware.common.CommonMiddleware",
    "mc.common.middleware.RequestIdMiddleware",
    "mc.common.middleware.RequestMetricsMiddleware",
    "mc.common.middleware.SecurityHeadersMiddleware",
]

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {"context_processors": ["django.template.context_processors.request"]},
    }
]

WSGI_APPLICATION = "config.wsgi.application"
ASGI_APPLICATION = "config.asgi.application"

DATABASES = {
    "default": database_from_url(env("DATABASE_URL", "postgres://mc:mc@localhost:5432/mc"))
}
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

REDIS_URL = env("REDIS_URL", "redis://localhost:6379/0")
CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels_redis.core.RedisChannelLayer",
        # channels_redis blocks on BZPOPMIN for up to 5 s per receive; redis-py 8 applies a default socket timeout that
        # kills the consumer ("Timeout reading from redis") on every idle socket. Give reads head-room explicitly.
        "CONFIG": {
            "hosts": [{"address": REDIS_URL, "socket_timeout": 30, "socket_connect_timeout": 5}]
        },
    }
}

# Celery (Bible §2.2): queues default, media, billing, notify.
CELERY_BROKER_URL = REDIS_URL
CELERY_TASK_DEFAULT_QUEUE = "default"
CELERY_TASK_ALWAYS_EAGER = False
CELERY_TASK_ACKS_LATE = True
CELERY_TASK_REJECT_ON_WORKER_LOST = True

REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": [],
    "UNAUTHENTICATED_USER": None,
    "UNAUTHENTICATED_TOKEN": None,
    "DEFAULT_PERMISSION_CLASSES": ["mc.common.permissions.DenyAll"],  # deny by default
    "DEFAULT_RENDERER_CLASSES": ["rest_framework.renderers.JSONRenderer"],
    "DEFAULT_PARSER_CLASSES": ["rest_framework.parsers.JSONParser"],
    "EXCEPTION_HANDLER": "mc.common.exception_handler.problem_exception_handler",
    "DEFAULT_SCHEMA_CLASS": "drf_spectacular.openapi.AutoSchema",
    "DEFAULT_THROTTLE_CLASSES": [],
}

SPECTACULAR_SETTINGS = {
    "TITLE": "Marriage Connect API",
    "VERSION": "1.0.0",
    "SERVE_INCLUDE_SCHEMA": False,
}

# Docs/OpenAPI are served in dev only (MC-012).
OPENAPI_ENABLED = False

LANGUAGE_CODE = "en"
TIME_ZONE = "UTC"
USE_I18N = True
USE_TZ = True

SECURE_CONTENT_TYPE_NOSNIFF = True
SECURE_REFERRER_POLICY = "same-origin"
X_FRAME_OPTIONS = "DENY"

LOG_LEVEL = env("LOG_LEVEL", "INFO")

# Crypto (Bible §12.1). Real environments inject MC_DATA_KEYS (wrapped DEKs), MC_DATA_KEY_CURRENT and
# peppers from Secrets Manager; local/test settings derive dev-only values (see local.py / test.py).
import json as _json

MC_DATA_KEYS: dict[str, str] = _json.loads(env("MC_DATA_KEYS_JSON", "{}"))
MC_DATA_KEY_CURRENT = env("MC_DATA_KEY_CURRENT", "k1")
MC_PEPPERS: dict[str, str] = _json.loads(env("MC_PEPPERS_JSON", "{}"))
MC_KMS = None  # production sets an AWS KMS-backed implementation of mc.common.crypto.Kms

# Observability
SENTRY_DSN = env("SENTRY_DSN", "")

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "filters": {"pii": {"()": "mc.common.logging.PiiScrubFilter"}},
    "formatters": {"json": {"()": "mc.common.logging.JsonFormatter"}},
    "handlers": {
        "console": {"class": "logging.StreamHandler", "formatter": "json", "filters": ["pii"]}
    },
    "root": {"handlers": ["console"], "level": LOG_LEVEL},
    "loggers": {"django.server": {"level": "WARNING"}},
}

# Metrics (Bible §15). `/metrics` is served ONLY on the admin host and needs `Authorization: Bearer <token>`;
# when METRICS_TOKEN is unset the endpoint is disabled (403), i.e. it fails closed.
METRICS_TOKEN = env("METRICS_TOKEN", "")
# Alert `queue_age_high`: oldest waiting task older than this (Bible §15: 5 minutes).
QUEUE_AGE_ALERT_SECONDS = int(env("QUEUE_AGE_ALERT_SECONDS", "300"))
CELERY_MONITORED_QUEUES = ("default", "media", "billing", "notify")
# Alert `payment_webhook_failures`: more than N failed PaymentEvents received in the window.
PAYMENT_WEBHOOK_FAILURE_THRESHOLD = int(env("PAYMENT_WEBHOOK_FAILURE_THRESHOLD", "5"))
PAYMENT_WEBHOOK_FAILURE_WINDOW_MINUTES = int(env("PAYMENT_WEBHOOK_FAILURE_WINDOW_MINUTES", "10"))

# Tracing (Bible §15): OpenTelemetry is OFF unless an OTLP endpoint is configured.
OTEL_EXPORTER_OTLP_ENDPOINT = env("OTEL_EXPORTER_OTLP_ENDPOINT", "")
OTEL_TRACES_SAMPLER_RATIO = float(env("OTEL_TRACES_SAMPLER_RATIO", "0.1"))
OTEL_SERVICE_NAME = env("OTEL_SERVICE_NAME", "mc-backend")

if SENTRY_DSN:
    import sentry_sdk

    from mc.common.logging import sentry_before_send

    sentry_sdk.init(
        dsn=SENTRY_DSN,
        send_default_pii=False,
        before_send=sentry_before_send,  # type: ignore[arg-type]
        traces_sample_rate=0.1,
    )

# SMS (Bible §11.4). Fake in local/test; real environments must set SMS_PROVIDER explicitly.
SMS_PROVIDER = env("SMS_PROVIDER", "mc.accounts.providers.sms.FakeSms")
AT_USERNAME = env("AT_USERNAME", "")
AT_API_KEY = env("AT_API_KEY", "")
AT_SENDER_ID = env("AT_SENDER_ID", "")
TWILIO_ACCOUNT_SID = env("TWILIO_ACCOUNT_SID", "")
TWILIO_AUTH_TOKEN = env("TWILIO_AUTH_TOKEN", "")
TWILIO_FROM = env("TWILIO_FROM", "")
TWILIO_MESSAGING_SERVICE_SID = env("TWILIO_MESSAGING_SERVICE_SID", "")

# JWT (Bible §12.1): asymmetric (EdDSA) keys from Secrets Manager; dev keys derived in local/test.
MC_JWT_PRIVATE_KEY_PEM = env("MC_JWT_PRIVATE_KEY_PEM", "")
MC_JWT_PUBLIC_KEY_PEM = env("MC_JWT_PUBLIC_KEY_PEM", "")

# Number of trusted reverse proxies (ALB=1) for X-Forwarded-For parsing.
MC_TRUSTED_PROXY_COUNT = int(env("MC_TRUSTED_PROXY_COUNT", "0"))

INSTALLED_APPS += ["mc.accounts"]
REST_FRAMEWORK["DEFAULT_AUTHENTICATION_CLASSES"] = ["mc.accounts.authentication.JWTAuthentication"]

# Identity verification (Bible §11.1). Fake in local/test; real environments must set explicitly.
IDENTITY_PROVIDER = env("IDENTITY_PROVIDER", "mc.verification.providers.fake.FakeIdentityProvider")
FAKE_IDENTITY_SECRET = env("FAKE_IDENTITY_SECRET", "fake-identity-secret")
SMILE_ID_PARTNER_ID = env("SMILE_ID_PARTNER_ID", "")
SMILE_ID_API_KEY = env("SMILE_ID_API_KEY", "")
SMILE_ID_ENV = env("SMILE_ID_ENV", "sandbox")
INSTALLED_APPS += ["mc.verification"]

CELERY_BEAT_SCHEDULE = {
    "queue-age-check": {
        "task": "mc.common.tasks.queue_age_check",
        "schedule": 60.0,
    },
    "verification-poll-stale": {
        "task": "mc.verification.tasks.poll_stale_attempts",
        "schedule": 300.0,
    },
}
INSTALLED_APPS += ["mc.entitlements"]
INSTALLED_APPS += ["mc.profiles"]
INSTALLED_APPS += ["mc.questionnaire"]

# Object storage (Bible §3.3): private S3 bucket (MinIO locally). Never public.
MEDIA_BUCKET = env("MEDIA_BUCKET", "media-private")
MEDIA_SSE = env("MEDIA_SSE", "")  # e.g. "aws:kms" in cloud
AWS_S3_ENDPOINT_URL = env("AWS_S3_ENDPOINT_URL", "")
AWS_REGION = env("AWS_REGION", "af-south-1")
AWS_ACCESS_KEY_ID = env("AWS_ACCESS_KEY_ID", "")
AWS_SECRET_ACCESS_KEY = env("AWS_SECRET_ACCESS_KEY", "")
MALWARE_SCANNER = env("MALWARE_SCANNER", "mc.media.providers.scanner.FakeScanner")
CLAMD_HOST = env("CLAMD_HOST", "localhost")
CLAMD_PORT = int(env("CLAMD_PORT", "3310"))
IMAGE_MODERATION_PROVIDER = env(
    "IMAGE_MODERATION_PROVIDER", "mc.media.providers.moderation.FakeModeration"
)
INSTALLED_APPS += ["mc.media"]
CELERY_TASK_ROUTES = {"mc.media.tasks.*": {"queue": "media"}}
INSTALLED_APPS += ["mc.safety", "mc.interests"]
INSTALLED_APPS += ["mc.discovery"]
INSTALLED_APPS += ["mc.matches"]
CELERY_BEAT_SCHEDULE["interests-expire"] = {
    "task": "mc.interests.tasks.expire_interests",
    "schedule": 900.0,
}
INSTALLED_APPS += ["mc.messaging"]

# Push (Bible §11.4)
PUSH_PROVIDER = env("PUSH_PROVIDER", "mc.notifications.providers.push.FakePush")
FCM_PROJECT_ID = env("FCM_PROJECT_ID", "")
FCM_SERVICE_ACCOUNT_JSON = env("FCM_SERVICE_ACCOUNT_JSON", "{}")
INSTALLED_APPS += ["mc.notifications"]
CELERY_BEAT_SCHEDULE["safety-lift-suspensions"] = {
    "task": "mc.safety.tasks.lift_expired_suspensions",
    "schedule": 600.0,
}
INSTALLED_APPS += ["mc.billing"]
CELERY_BEAT_SCHEDULE["billing-expire-purchases"] = {
    "task": "mc.billing.tasks.expire_purchases",
    "schedule": 3600.0,
}
CELERY_BEAT_SCHEDULE["billing-webhook-failure-check"] = {
    "task": "mc.billing.tasks.check_webhook_failures",
    "schedule": 300.0,
}
CELERY_BEAT_SCHEDULE["billing-retry-failed"] = {
    "task": "mc.billing.tasks.retry_failed",
    "schedule": 600.0,
}

# Store billing (Bible §11.2). Root certificates and credentials are injected per environment.
APPLE_BUNDLE_ID = env("APPLE_BUNDLE_ID", "ug.marriageconnect.app")
APPLE_ENVIRONMENT = env("APPLE_ENVIRONMENT", "Sandbox")  # Production | Sandbox
APPLE_ROOT_CERTS_PEM: list[str] = _json.loads(
    env("APPLE_ROOT_CERTS_PEM_JSON", "[]")
)  # Apple Root CA - G3
GOOGLE_PACKAGE_NAME = env("GOOGLE_PACKAGE_NAME", "ug.marriageconnect.app")
GOOGLE_RTDN_AUDIENCE = env("GOOGLE_RTDN_AUDIENCE", "")
GOOGLE_RTDN_SERVICE_ACCOUNT = env("GOOGLE_RTDN_SERVICE_ACCOUNT", "")
GOOGLE_SERVICE_ACCOUNT_JSON = env("GOOGLE_SERVICE_ACCOUNT_JSON", "{}")
STORE_PROVIDER_APPLE = env("STORE_PROVIDER_APPLE", "mc.billing.providers.apple.AppleStore")
STORE_PROVIDER_GOOGLE = env("STORE_PROVIDER_GOOGLE", "mc.billing.providers.google.GooglePlayStore")

# Web checkout (Bible §11.3)
PAYMENT_GATEWAY = env("PAYMENT_GATEWAY", "mc.billing.providers.flutterwave.FakeGateway")
FLUTTERWAVE_SECRET_KEY = env("FLUTTERWAVE_SECRET_KEY", "")
FLUTTERWAVE_WEBHOOK_HASH = env("FLUTTERWAVE_WEBHOOK_HASH", "fake-webhook-hash")
CHECKOUT_REDIRECT_URL = env("CHECKOUT_REDIRECT_URL", "https://pay.localtest.me/checkout/return")
CELERY_BEAT_SCHEDULE["billing-sweep-pending-web"] = {
    "task": "mc.billing.tasks.sweep_pending_web",
    "schedule": 600.0,
}
CELERY_BEAT_SCHEDULE["billing-nightly-reconciliation"] = {
    "task": "mc.billing.tasks.nightly_reconciliation",
    "schedule": 86400.0,
}
INSTALLED_APPS += ["mc.privacy"]
CELERY_BEAT_SCHEDULE["privacy-hard-deletions"] = {
    "task": "mc.privacy.tasks.run_hard_deletions",
    "schedule": 86400.0,
}
EXPORTS_BUCKET = env("EXPORTS_BUCKET", "exports-private")
CELERY_BEAT_SCHEDULE["privacy-purge-exports"] = {
    "task": "mc.privacy.tasks.purge_expired_exports",
    "schedule": 3600.0,
}
CELERY_BEAT_SCHEDULE["privacy-retention"] = {
    "task": "mc.privacy.tasks.run_retention",
    "schedule": 86400.0,
}

# Email (recovery + notices)
EMAIL_PROVIDER = env("EMAIL_PROVIDER", "mc.accounts.providers.email.FakeEmail")
EMAIL_FROM = env("EMAIL_FROM", "no-reply@marriageconnect.ug")

# Admin portal (Bible §6.3, §12.4)
STAFF_SSO_PROVIDER = env("STAFF_SSO_PROVIDER", "mc.adminportal.providers.sso.FakeSso")
STAFF_OIDC_ISSUER = env("STAFF_OIDC_ISSUER", "")
STAFF_OIDC_CLIENT_ID = env("STAFF_OIDC_CLIENT_ID", "")
STAFF_OIDC_CLIENT_SECRET = env("STAFF_OIDC_CLIENT_SECRET", "")
STAFF_ALLOWED_EMAIL_DOMAINS = [
    d for d in env("STAFF_ALLOWED_EMAIL_DOMAINS", "marriageconnect.ug").split(",") if d
]
STAFF_SESSION_HOURS = int(env("STAFF_SESSION_HOURS", "8"))
STAFF_REAUTH_MINUTES = int(env("STAFF_REAUTH_MINUTES", "10"))
ADMIN_IP_ALLOWLIST = [
    c for c in env("ADMIN_IP_ALLOWLIST", "").split(",") if c
]  # CIDRs; empty = any
STAFF_COOKIE = "mc_admin"
INSTALLED_APPS += ["mc.adminportal"]
INSTALLED_APPS += ["mc.webcheckout"]

# Closed beta (MC-127)
BETA_INVITE_REQUIRED = env("BETA_INVITE_REQUIRED", "false").lower() == "true"
INSTALLED_APPS += ["mc.beta"]
INSTALLED_APPS += ["mc.flags"]

# Android SMS Retriever (OTP autofill without permissions): the 11-char app hash for the signing key; empty = plain SMS.
SMS_RETRIEVER_APP_HASH = env("SMS_RETRIEVER_APP_HASH", "")

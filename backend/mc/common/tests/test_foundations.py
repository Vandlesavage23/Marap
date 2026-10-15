import json
import time
import uuid

import pytest
from django.db import connection
from django.test import Client
from rest_framework.response import Response
from rest_framework.test import APIRequestFactory
from rest_framework.views import APIView

from mc.common import errors, events, ratelimit
from mc.common.exception_handler import problem_exception_handler
from mc.common.idempotency import IdempotentMixin, run_idempotent
from mc.common.ids import uuid7

pytestmark = pytest.mark.django_db


# ---- ids ----------------------------------------------------------------
def test_uuid7_version_and_ordering():
    ids = []
    for _ in range(50):
        ids.append(uuid7())
        time.sleep(0.001)
    assert all(i.version == 7 for i in ids)
    assert ids == sorted(ids)
    assert len(set(ids)) == 50


# ---- host routing / health ----------------------------------------------
def test_health_ok(api):
    r = api.get("/api/v1/health")
    assert r.status_code == 200 and r.json() == {"status": "ok"}
    assert r["X-Request-Id"]


def test_ready_checks_db_and_redis(api):
    assert api.get("/api/v1/ready").status_code == 200
    assert api.get("/ready").status_code == 200


def test_ready_503_when_db_down(api, monkeypatch):
    class Boom:
        def __enter__(self):
            raise RuntimeError("db down")

        def __exit__(self, *a):
            return False

    monkeypatch.setattr(connection, "cursor", lambda: Boom())
    r = api.get("/api/v1/ready")
    assert r.status_code == 503
    assert "db down" not in r.content.decode()


def test_unknown_host_is_400():
    assert Client(headers={"host": "evil.example.com"}).get("/api/v1/health").status_code == 400
    assert Client(headers={"host": "mc.test"}).get("/api/v1/health").status_code == 400


def test_admin_and_pay_hosts_route_separately():
    assert Client(headers={"host": "admin.mc.test"}).get("/api/v1/health").status_code == 404
    assert Client(headers={"host": "pay.mc.test"}).get("/api/v1/health").status_code == 404


def test_openapi_served_in_dev_only(api, monkeypatch):
    assert api.get("/api/v1/schema/").status_code == 200
    monkeypatch.setenv("DJANGO_SECRET_KEY", "x")
    monkeypatch.setenv("SMS_PROVIDER", "mc.accounts.providers.sms.AfricasTalkingSms")
    monkeypatch.setenv("IDENTITY_PROVIDER", "mc.verification.providers.smile_id.SmileIdProvider")
    monkeypatch.setenv("MALWARE_SCANNER", "mc.media.providers.scanner.ClamdScanner")
    monkeypatch.setenv("PUSH_PROVIDER", "mc.notifications.providers.push.FcmPush")
    monkeypatch.setenv("PAYMENT_GATEWAY", "mc.billing.providers.flutterwave.FlutterwaveGateway")
    monkeypatch.setenv("EMAIL_PROVIDER", "mc.accounts.providers.email.SesEmail")
    monkeypatch.setenv(
        "IMAGE_MODERATION_PROVIDER", "mc.media.providers.moderation.RekognitionModeration"
    )
    import importlib

    prod = importlib.import_module("config.settings.prod")
    assert prod.OPENAPI_ENABLED is False
    staging = importlib.import_module("config.settings.staging")
    assert staging.OPENAPI_ENABLED is False


def test_default_permission_is_deny():
    class Open(APIView):
        def get(self, request):
            return Response({"leak": True})

    request = APIRequestFactory().get("/x")
    resp = Open.as_view()(request)
    assert resp.status_code == 401  # anonymous → authenticate first; authenticated → 403 forbidden
    resp.render()
    assert json.loads(resp.content)["code"] == "unauthenticated"
    assert resp["Content-Type"].startswith("application/problem+json")


# ---- errors --------------------------------------------------------------
@pytest.mark.parametrize(
    ("exc", "status", "code"),
    [
        (errors.EntitlementRequired("x", capability="send_interest"), 403, "entitlement_required"),
        (errors.NotFound(), 404, "not_found"),
        (errors.Duplicate(), 409, "duplicate"),
        (errors.LimitReached(), 429, "limit_reached"),
        (errors.ValidationFailed(), 422, "validation_error"),
        (errors.Unauthenticated(), 401, "unauthenticated"),
    ],
)
def test_domain_errors_map_to_problem_json(exc, status, code):
    resp = problem_exception_handler(exc, {})
    assert resp.status_code == status
    assert resp.data["code"] == code
    assert resp.data["status"] == status
    assert resp.data["type"].endswith(code)
    if isinstance(exc, errors.EntitlementRequired):
        assert resp.data["capability"] == "send_interest"


def test_rate_limited_has_retry_after():
    resp = problem_exception_handler(errors.RateLimited(retry_after=42), {})
    assert resp.status_code == 429 and resp["Retry-After"] == "42"


def test_every_documented_code_exists():
    documented = {
        "validation_error",
        "unauthenticated",
        "token_expired",
        "forbidden",
        "not_found",
        "rate_limited",
        "not_verified",
        "underage",
        "verification_pending",
        "entitlement_required",
        "trial_already_used",
        "not_eligible",
        "blocked",
        "duplicate",
        "profile_incomplete",
        "description_rejected",
        "married_not_eligible",
        "limit_reached",
        "payment_pending",
        "provider_error",
        "conflict",
    }
    assert documented <= errors.STABLE_CODES


# ---- idempotency ---------------------------------------------------------
def test_idempotent_replay_returns_same_status_and_body():
    calls = []

    def fn():
        calls.append(1)
        return 201, {"id": str(uuid.uuid4())}

    s1, b1, r1 = run_idempotent(scope="a", key="key-12345678", payload={"x": 1}, fn=fn)
    s2, b2, r2 = run_idempotent(scope="a", key="key-12345678", payload={"x": 1}, fn=fn)
    assert (s1, b1, r1) == (201, b1, False)
    assert (s2, b2, r2) == (201, b1, True)
    assert len(calls) == 1


def test_idempotency_scoped_per_account():
    calls = []
    for scope in ("acct-a", "acct-b"):
        run_idempotent(
            scope=scope, key="same-key-123", payload={}, fn=lambda: calls.append(1) or (200, {})
        )
    assert len(calls) == 2


def test_idempotency_key_reuse_with_different_body_conflicts():
    run_idempotent(scope="a", key="key-12345678", payload={"x": 1}, fn=lambda: (200, {}))
    with pytest.raises(errors.Conflict):
        run_idempotent(scope="a", key="key-12345678", payload={"x": 2}, fn=lambda: (200, {}))


def test_idempotency_failure_releases_key_for_retry():
    def boom():
        raise RuntimeError("transient")

    with pytest.raises(RuntimeError):
        run_idempotent(scope="a", key="key-12345678", payload={}, fn=boom)
    status, _, replayed = run_idempotent(
        scope="a", key="key-12345678", payload={}, fn=lambda: (200, {})
    )
    assert status == 200 and not replayed


def test_idempotency_in_flight_duplicate_conflicts():
    from mc.common.redis import get_redis

    get_redis().set("idem:a:key-12345678:lock", "1", ex=30)
    with pytest.raises(errors.Conflict):
        run_idempotent(scope="a", key="key-12345678", payload={}, fn=lambda: (200, {}))


def test_idempotent_mixin_end_to_end():
    from rest_framework.permissions import AllowAny

    class Create(IdempotentMixin):
        permission_classes = [AllowAny]
        n = 0

        def perform_idempotent(self, request):
            Create.n += 1
            return 201, {"n": Create.n}

    factory = APIRequestFactory()
    view = Create.as_view()
    r1 = view(
        factory.post("/x", {"a": 1}, format="json", headers={"Idempotency-Key": "abcdefgh-1"})
    )
    r2 = view(
        factory.post("/x", {"a": 1}, format="json", headers={"Idempotency-Key": "abcdefgh-1"})
    )
    assert r1.status_code == r2.status_code == 201
    assert r1.data == r2.data == {"n": 1}
    assert r2["Idempotent-Replayed"] == "true"
    missing = view(factory.post("/x", {"a": 1}, format="json"))
    assert missing.status_code == 422
    bad = view(factory.post("/x", {}, format="json", headers={"Idempotency-Key": "short"}))
    assert bad.status_code == 422


# ---- rate limit ----------------------------------------------------------
def test_ratelimit_blocks_after_limit_with_retry_after():
    for _ in range(3):
        ratelimit.hit("otp:phone:x", limit=3, window_seconds=60)
    with pytest.raises(errors.RateLimited) as ei:
        ratelimit.hit("otp:phone:x", limit=3, window_seconds=60)
    assert 1 <= ei.value.retry_after <= 60
    ratelimit.hit("otp:phone:y", limit=3, window_seconds=60)  # other bucket unaffected


# ---- events --------------------------------------------------------------
def test_events_dispatch_only_after_commit(django_capture_on_commit_callbacks):
    from dataclasses import dataclass

    @dataclass(frozen=True)
    class Pinged(events.DomainEvent):
        n: int

    got = []
    events.subscribe(Pinged)(lambda e: got.append(e.n))
    with django_capture_on_commit_callbacks(execute=False) as cbs:
        events.publish(Pinged(1))
    assert got == []  # nothing before commit
    for cb in cbs:
        cb()
    assert got == [1]


def test_events_failing_handler_does_not_block_others(django_capture_on_commit_callbacks):
    from dataclasses import dataclass

    @dataclass(frozen=True)
    class Pong(events.DomainEvent):
        pass

    got = []

    def bad(e):
        raise RuntimeError("x")

    events.subscribe(Pong)(bad)
    events.subscribe(Pong)(lambda e: got.append(1))
    with django_capture_on_commit_callbacks(execute=True):
        events.publish(Pong())
    assert got == [1]

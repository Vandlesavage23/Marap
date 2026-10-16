"""The committed OpenAPI file (docs/api/openapi.yaml) is the API contract. These tests are CI's "schema diff" step:
change an endpoint, a serializer or a limit and the file must be regenerated and committed with it."""

import yaml
from django.urls import get_resolver

from mc.common import openapi_export

REGENERATE = (
    "run `uv run python scripts/export_openapi.py` (from backend/) and commit docs/api/openapi.yaml"
)

# Endpoints that need no bearer token (Bible §8.2 "public"). Everything else must declare `bearerAuth`.
PUBLIC = {
    ("/api/v1/auth/otp/start", "post"), ("/api/v1/auth/otp/verify", "post"), ("/api/v1/auth/refresh", "post"),
    ("/api/v1/auth/recover/start", "post"), ("/api/v1/auth/recover/verify-email", "post"),
    ("/api/v1/auth/recover/status", "post"), ("/api/v1/auth/recover/new-phone", "post"),
    ("/api/v1/auth/recover/complete", "post"), ("/api/v1/config/flags", "get"),
    ("/api/v1/health", "get"), ("/api/v1/ready", "get"), ("/health", "get"), ("/ready", "get"),
    ("/api/v1/webhooks/apple", "post"), ("/api/v1/webhooks/flutterwave", "post"),
    ("/api/v1/webhooks/google", "post"), ("/api/v1/webhooks/smile-id", "post"),
}  # fmt: skip
METHODS = {"get", "post", "put", "patch", "delete"}


def test_committed_schema_is_up_to_date():
    committed = openapi_export.COMMITTED
    assert committed.exists(), f"missing {committed}: {REGENERATE}"
    assert committed.read_text() == openapi_export.render(), (
        f"docs/api/openapi.yaml is stale: {REGENERATE}"
    )


def test_generation_is_deterministic_and_has_no_warnings():
    assert (
        openapi_export.render() == openapi_export.render()
    )  # render() raises on any spectacular warning/error


def _schema() -> dict:
    return yaml.safe_load(openapi_export.COMMITTED.read_text())


def _routes(resolver, prefix=""):
    for p in resolver.url_patterns:
        text = prefix + str(p.pattern)
        if hasattr(p, "url_patterns"):
            yield from _routes(p, text)
        else:
            yield text


def test_every_api_route_is_in_the_contract():
    import re

    documented = {re.sub(r"\{[^}]+\}", "{}", path) for path in _schema()["paths"]}
    missing = []
    for route in _routes(get_resolver("config.urls_api")):
        if route.startswith(("api/v1/schema", "api/v1/docs")):
            continue
        normal = "/" + re.sub(r"<[^>]+>", "{}", route).rstrip("$^")
        if normal not in documented:
            missing.append(normal)
    assert not missing, f"routes absent from the OpenAPI file ({REGENERATE}): {missing}"


def test_only_the_public_endpoints_skip_bearer_auth():
    open_ops, unlisted = set(), []
    for path, ops in _schema()["paths"].items():
        for method, op in ops.items():
            if method not in METHODS:
                continue
            secured = any("bearerAuth" in req for req in op.get("security", []))
            if not secured:
                open_ops.add((path, method))
            if path.endswith("/uploads") and not secured:
                unlisted.append(path)
    assert open_ops == PUBLIC, f"unexpected unauthenticated operations: {sorted(open_ops ^ PUBLIC)}"
    assert not unlisted


def test_new_endpoints_of_this_release_are_documented():
    paths = _schema()["paths"]
    assert "get" in paths["/api/v1/me/devices"] and "post" in paths["/api/v1/me/devices"]
    assert "get" in paths["/api/v1/config/flags"]


def test_advertised_limits_match_the_enforced_ones(settings):
    comps = _schema()["components"]["schemas"]
    assert comps["VerificationAppeal"]["properties"]["message"]["minLength"] == 10
    assert comps["VerificationAppeal"]["properties"]["message"]["maxLength"] == 1000
    assert comps["SafetyAppeal"]["properties"]["message"]["maxLength"] == 1000
    assert comps["PatchedProfileUpdate"]["properties"]["display_name"]["maxLength"] == 30
    assert comps["Description"]["properties"]["text"]["maxLength"] == settings.DESCRIPTION_MAX
    assert comps["SendMessage"]["properties"]["body"]["maxLength"] == settings.MESSAGE_MAX_CHARS
    assert comps["Report"]["properties"]["text"]["maxLength"] == 1000

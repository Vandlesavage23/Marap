"""Deterministic OpenAPI export (docs/api/openapi.yaml). The committed file is the API contract; the CI "schema
diff" step and `tests/test_openapi_contract.py` fail when the code and the file disagree."""

from pathlib import Path

from django.conf import settings

COMMITTED = Path(settings.BASE_DIR).parent / "docs" / "api" / "openapi.yaml"


def render() -> str:
    """The public API schema as YAML. Raises if drf-spectacular reports any warning or error (an undocumented or
    ambiguous endpoint is a contract bug, not something to paper over)."""
    from drf_spectacular.drainage import GENERATOR_STATS
    from drf_spectacular.generators import SchemaGenerator
    from drf_spectacular.renderers import OpenApiYamlRenderer

    GENERATOR_STATS.reset()
    schema = SchemaGenerator(urlconf="config.urls_api").get_schema(request=None, public=True)
    problems = {**GENERATOR_STATS._warn_cache, **GENERATOR_STATS._error_cache}
    if problems:
        raise RuntimeError("OpenAPI generation reported problems:\n" + "\n".join(sorted(problems)))
    return OpenApiYamlRenderer().render(schema, renderer_context={}).decode()

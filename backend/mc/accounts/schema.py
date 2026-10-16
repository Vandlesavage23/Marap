"""OpenAPI description of our bearer-token authentication (registers itself on import; see `AccountsConfig.ready`)."""

from drf_spectacular.extensions import OpenApiAuthenticationExtension


class JWTAuthenticationScheme(OpenApiAuthenticationExtension):
    target_class = "mc.accounts.authentication.JWTAuthentication"
    name = "bearerAuth"

    def get_security_definition(self, auto_schema):  # type: ignore[no-untyped-def]
        return {"type": "http", "scheme": "bearer", "bearerFormat": "JWT"}

"""Domain errors with stable `code`s (Bible §8.1). Services raise these, never HTTP responses;
the DRF exception handler maps them to RFC 9457 problem+json."""

from typing import Any


class DomainError(Exception):
    code = "conflict"
    status = 409
    title = "Conflict"

    def __init__(self, detail: str | None = None, **extra: Any) -> None:
        self.detail = detail or self.title
        self.extra = extra
        super().__init__(self.detail)


class ValidationFailed(DomainError):
    code, status, title = "validation_error", 422, "Validation error"


class Unauthenticated(DomainError):
    code, status, title = "unauthenticated", 401, "Authentication required"


class TokenExpired(DomainError):
    code, status, title = "token_expired", 401, "Token expired"


class Forbidden(DomainError):
    code, status, title = "forbidden", 403, "Forbidden"


class NotFound(DomainError):
    code, status, title = "not_found", 404, "Not found"


class RateLimited(DomainError):
    code, status, title = "rate_limited", 429, "Too many requests"

    def __init__(self, detail: str | None = None, *, retry_after: int = 60, **extra: Any) -> None:
        super().__init__(detail, **extra)
        self.retry_after = retry_after


class NotVerified(DomainError):
    code, status, title = "not_verified", 403, "Identity verification required"


class Underage(DomainError):
    code, status, title = "underage", 403, "Not eligible"


class VerificationPending(DomainError):
    code, status, title = "verification_pending", 403, "Verification pending"


class EntitlementRequired(DomainError):
    code, status, title = "entitlement_required", 403, "Membership required"


class TrialAlreadyUsed(DomainError):
    code, status, title = "trial_already_used", 409, "Trial already used"


class NotEligible(DomainError):
    code, status, title = "not_eligible", 403, "Not eligible"


class Blocked(DomainError):
    code, status, title = "blocked", 403, "Not eligible"


class Duplicate(DomainError):
    code, status, title = "duplicate", 409, "Already exists"


class ProfileIncomplete(DomainError):
    code, status, title = "profile_incomplete", 422, "Profile incomplete"


class DescriptionRejected(DomainError):
    code, status, title = "description_rejected", 422, "Description rejected"


class MarriedNotEligible(DomainError):
    code, status, title = "married_not_eligible", 422, "Not eligible for this status"


class LimitReached(DomainError):
    code, status, title = "limit_reached", 429, "Limit reached"


class PaymentPending(DomainError):
    code, status, title = "payment_pending", 402, "Payment pending"


class ProviderError(DomainError):
    code, status, title = "provider_error", 502, "Upstream provider error"


class Conflict(DomainError):
    code, status, title = "conflict", 409, "Conflict"


STABLE_CODES = frozenset(cls.code for cls in DomainError.__subclasses__())

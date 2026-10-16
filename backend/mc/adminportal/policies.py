"""Admin access matrix (Bible §12.4). Single source of truth: `PERMISSIONS` maps each role to what it may do.
Anything not listed is denied. `superadmin` break-glass (dual approval, time-boxed) is a separate mechanism and
grants nothing by itself."""

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from .models import StaffUser

# Dashboards (Bible §15) are aggregate-only (no member rows; cells under 5 suppressed). The matrix in §12.4 has no
# column for them, so: `dashboard.funnel` (conversion) -> payments_ops, privacy_officer; `dashboard.density` (where live
# profiles are) -> trust_safety, privacy_officer; `payments.reconciliation` -> the roles with full payments access.
# engineer_oncall stays at "no production data" and superadmin grants nothing by itself (OPEN_QUESTIONS Q22/Q30).
PERMISSIONS: dict[str, frozenset[str]] = {
    # Users & profiles: read limited (no answers, no special data)
    "support": frozenset(
        {
            "user.read_limited",
            "user.revoke_sessions",
            "user.add_note",
            "verification.status",
            "payments.status",
            "entitlement.read",
        }
    ),
    "verification_reviewer": frozenset(
        {"verification.queue", "verification.decide", "verification.appeals"}
    ),
    "trust_safety": frozenset(
        {
            "user.read_limited",
            "safety.queue",
            "safety.evidence",
            "safety.act",
            "safety.appeals",
            "verification.status",
            "audit.own",
            "dashboard.density",
        }
    ),
    "payments_ops": frozenset(
        {
            "user.read_basic",
            "payments.full",
            "payments.refund",
            "payments.reconciliation",
            "entitlement.read",
            "entitlement.grant",
            "dashboard.funnel",
        }
    ),
    "privacy_officer": frozenset(
        {
            "user.read_limited",
            "user.read_with_reason",
            "safety.evidence_with_reason",
            "verification.status",
            "payments.full",
            "audit.all",
            "privacy.requests",
            "privacy.cancel_deletion",
            "entitlement.read",
            "payments.reconciliation",
            "dashboard.funnel",
            "dashboard.density",
        }
    ),
    "engineer_oncall": frozenset({"config.flags"}),
    "superadmin": frozenset({"config.flags", "staff.manage"}),
}
SENSITIVE = frozenset({
    "safety.act", "payments.refund", "entitlement.grant", "privacy.cancel_deletion", "verification.decide",
    "user.revoke_sessions", "staff.manage",
})  # fmt: skip
REASON_REQUIRED = frozenset({"user.read_with_reason", "safety.evidence_with_reason"})


IMPLIES = {
    "payments.full": frozenset({"payments.status"})
}  # a broader grant covers the narrower read


def permissions_of(staff: "StaffUser") -> frozenset[str]:
    out: set[str] = set()
    for role in staff.roles:
        out |= PERMISSIONS.get(role, frozenset())
    for perm in tuple(out):
        out |= IMPLIES.get(perm, frozenset())
    return frozenset(out)


def can(staff: "StaffUser", permission: str) -> bool:
    return staff.active and permission in permissions_of(staff)


def primary_role(staff: "StaffUser", permission: str) -> str:
    """The role that grants `permission` (for audit rows)."""
    for role in staff.roles:
        granted = PERMISSIONS.get(role, frozenset())
        if permission in granted or any(permission in IMPLIES.get(g, ()) for g in granted):
            return role
    return ",".join(staff.roles)

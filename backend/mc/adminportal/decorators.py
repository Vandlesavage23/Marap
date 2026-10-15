"""`staff_required(permission)` — the single gate for every portal view: session → MFA → IP allowlist → permission
→ (step-up for sensitive actions). Denials are audited and raise an alert-tagged WARNING (scenario 12)."""

import functools
import logging
from collections.abc import Callable
from typing import Any

from django.http import HttpRequest, HttpResponse, HttpResponseForbidden
from django.shortcuts import redirect
from django.views.decorators.csrf import csrf_protect

from mc.audit import services as audit
from mc.common.net import client_ip

from . import auth, policies
from .models import StaffSession, StaffUser


class StaffRequest(HttpRequest):
    staff: StaffUser
    staff_session: StaffSession


log = logging.getLogger("mc.adminportal")


def deny(request: HttpRequest, permission: str, why: str) -> HttpResponse:
    staff = getattr(request, "staff", None)
    audit.record(
        actor_type="staff", actor_id=staff.id if staff else None, role=",".join(staff.roles) if staff else "",
        action="admin.denied", target_type="permission", reason=f"{permission}: {why}", ip=client_ip(request),
        metadata={"path": request.path[:120], "permission": permission},
    )  # fmt: skip
    log.warning(
        "admin access denied",
        extra={"alert": "admin_access_denied", "permission": permission, "why": why},
    )
    return HttpResponseForbidden("You don't have access to this.")


def staff_required(
    permission: str | None = None, *, sensitive: bool | None = None
) -> Callable[..., Any]:
    """`permission=None` means any signed-in, MFA-verified staff member (e.g. the home page)."""
    needs_stepup = (permission in policies.SENSITIVE) if sensitive is None else sensitive

    def wrap(view: Callable[..., HttpResponse]) -> Callable[..., HttpResponse]:
        @csrf_protect
        @functools.wraps(view)
        def inner(request: HttpRequest, *args: Any, **kwargs: Any) -> HttpResponse:
            if not auth.ip_allowed(client_ip(request)):
                return deny(request, permission or "-", "ip_not_allowed")
            session = auth.load_session(auth.read_cookie(request))
            if session is None:
                return redirect("admin-login")
            request.staff, request.staff_session = session.staff, session  # type: ignore[attr-defined]
            if session.mfa_verified_at is None:
                return redirect("admin-mfa")
            if permission and not policies.can(session.staff, permission):
                return deny(request, permission, "role")
            if needs_stepup and not auth.recently_reauthed(session):
                return redirect(f"/stepup?next={request.path}")
            if permission:
                audit.record(
                    actor_type="staff", actor_id=session.staff.id, role=policies.primary_role(session.staff, permission),
                    action="admin.view", target_type="page", reason=permission, ip=client_ip(request),
                    metadata={"path": request.path[:120], "method": request.method or ""},
                )  # fmt: skip
            return view(request, *args, **kwargs)

        return inner

    return wrap

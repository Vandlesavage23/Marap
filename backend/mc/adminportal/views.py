"""Staff portal (MC-113): server-rendered, CSRF-protected, every view behind `staff_required`."""

import uuid
from collections.abc import Callable
from typing import Any

from django.conf import settings
from django.http import HttpRequest, HttpResponse
from django.shortcuts import redirect, render
from django.utils import timezone
from django.views.decorators.csrf import csrf_protect

from mc.accounts import phone as phone_lib
from mc.accounts import selectors as account_selectors
from mc.accounts import services as account_services
from mc.audit import selectors as audit_selectors
from mc.audit import services as audit
from mc.billing import admin_ops
from mc.common import aggregates
from mc.common.errors import DomainError, RateLimited
from mc.common.net import client_ip
from mc.entitlements import selectors as entitlement_selectors
from mc.flags import selectors as flag_selectors
from mc.flags import services as flag_services
from mc.privacy import selectors as privacy_selectors
from mc.privacy import services as privacy_services
from mc.profiles import selectors as profile_selectors
from mc.safety import enforcement
from mc.safety import selectors as safety_selectors
from mc.verification import review
from mc.verification import selectors as verification_selectors

from . import auth, dashboards, policies, services
from .decorators import StaffRequest, staff_required

ACTION_KINDS = ["warn", "hide_content", "suspend_7d", "ban", "reinstate"]


def _uuid(raw: str) -> uuid.UUID | None:
    try:
        return uuid.UUID(raw)
    except (ValueError, AttributeError):
        return None


def _page(request: HttpRequest, template: str, **ctx: Any) -> HttpResponse:
    staff = getattr(request, "staff", None)
    ctx.update(staff=staff, perms=policies.permissions_of(staff) if staff else frozenset())
    return render(request, f"adminportal/{template}", ctx)


def _run(request: HttpRequest, fn: Callable[[], Any], ok: str) -> str:
    """Run a service call and return a flash message (domain errors become the message, not a 500)."""
    try:
        fn()
        return ok
    except DomainError as exc:
        return exc.detail


def _who(request: StaffRequest, permission: str) -> dict[str, Any]:
    return {"actor_id": request.staff.id, "role": policies.primary_role(request.staff, permission)}


# ------------------------------------------------------------------------------------------------ auth
def _redirect_uri(request: HttpRequest) -> str:
    return request.build_absolute_uri("/sso/callback")


@csrf_protect
def login(request: HttpRequest) -> HttpResponse:
    if not auth.ip_allowed(client_ip(request)):
        return HttpResponse("Not available from this network.", status=403)
    url, state, nonce = auth.begin_sso(redirect_uri=_redirect_uri(request))
    resp = _page(request, "login.html", sso_url=url)
    resp.set_cookie(
        auth.STATE_COOKIE,
        auth.sign_state(state, nonce),
        max_age=600,
        httponly=True,
        samesite="Lax",
        secure=settings.SESSION_COOKIE_SECURE,
    )
    return resp


def sso_callback(request: HttpRequest) -> HttpResponse:
    ip = client_ip(request)
    if not auth.ip_allowed(ip):
        return HttpResponse("Not available from this network.", status=403)
    try:
        _, token = auth.complete_sso(
            code=request.GET.get("code", ""), state=request.GET.get("state", ""),
            cookie_state=request.COOKIES.get(auth.STATE_COOKIE, ""), redirect_uri=_redirect_uri(request), ip=ip,
        )  # fmt: skip
    except DomainError:
        audit.record(actor_type="staff", action="admin.login_failed", reason="sso rejected", ip=ip)
        return HttpResponse("Sign-in failed.", status=401)
    resp = redirect("admin-mfa")
    auth.set_cookie(resp, token)
    resp.delete_cookie(auth.STATE_COOKIE)
    return resp


@csrf_protect
def mfa(request: HttpRequest) -> HttpResponse:
    from . import totp

    session = auth.load_session(auth.read_cookie(request))
    if session is None:
        return redirect("admin-login")
    request.staff = session.staff  # type: ignore[attr-defined]
    status = 200
    enrolling = session.staff.totp_enrolled_at is None
    msg = ""
    if request.method == "POST":
        try:
            auth.verify_mfa(session, request.POST.get("code", ""))
            audit.record(
                actor_type="staff",
                actor_id=session.staff.id,
                role=",".join(session.staff.roles),
                action="admin.login",
                ip=client_ip(request),
            )
            return redirect(auth.safe_next(request.GET.get("next")))
        except DomainError as exc:
            msg = exc.title
            status = exc.status if isinstance(exc, RateLimited) else 200
            audit.record(
                actor_type="staff",
                actor_id=session.staff.id,
                action="admin.mfa_failed",
                ip=client_ip(request),
            )
    uri = (
        totp.provisioning_uri(auth.enrol_secret(session.staff), session.staff.email)
        if enrolling
        else ""
    )
    resp = _page(request, "mfa.html", enrolling=enrolling, otpauth=uri, msg=msg)
    resp.status_code = status
    return resp


@staff_required(None)
def stepup(request: StaffRequest) -> HttpResponse:
    msg = ""
    nxt = auth.safe_next(request.GET.get("next"))
    status = 200
    if request.method == "POST":
        try:
            auth.step_up(request.staff_session, request.POST.get("code", ""))
            return redirect(nxt)
        except DomainError as exc:
            msg = exc.title
            status = exc.status if isinstance(exc, RateLimited) else 200
            audit.record(
                actor_type="staff", actor_id=request.staff.id, action="admin.mfa_failed",
                reason="step-up", ip=client_ip(request),
            )  # fmt: skip
    resp = _page(request, "stepup.html", msg=msg, next=nxt)
    resp.status_code = status
    return resp


@staff_required(None)
def logout(request: StaffRequest) -> HttpResponse:
    if request.method == "POST":
        auth.logout(request.staff_session)
        resp = redirect("admin-login")
        resp.delete_cookie(settings.STAFF_COOKIE)
        return resp
    return redirect("admin-home")


@staff_required(None)
def home(request: StaffRequest) -> HttpResponse:
    return _page(request, "home.html")


# ------------------------------------------------------------------------------------------------ users (support)
@staff_required("user.read_limited")
def users(request: StaffRequest) -> HttpResponse:
    q = request.GET.get("q", "").strip()
    found, ent, ver, msg, notes = None, None, None, "", []
    acc = None
    if q:
        uid = _uuid(q)
        acc = account_selectors.get_account(uid) if uid else None
        if acc is None and q.startswith(("+", "0", "2")):
            try:
                acc = account_selectors.get_account_by_phone(phone_lib.normalise(q))
            except Exception:  # invalid number → not found
                acc = None
        if acc is None:
            msg = "No member found."
        else:
            audit.record(
                actor_type="staff",
                actor_id=request.staff.id,
                role=policies.primary_role(request.staff, "user.read_limited"),
                action="admin.view_user",
                target_type="account",
                target_id=acc.id,
                reason="support lookup",
                ip=client_ip(request),
            )
            found = account_selectors.staff_summary(acc)
            notes = services.notes_for(acc.id)
            ver = verification_selectors.latest_status(acc)
            if policies.can(request.staff, "entitlement.read"):
                ent = entitlement_selectors.entitlement_summary(acc)
    return _page(request, "users.html", q=q, found=found, ent=ent, ver=ver, msg=msg, notes=notes)


@staff_required("user.revoke_sessions")
def revoke_sessions(request: StaffRequest, account_id: uuid.UUID) -> HttpResponse:
    msg = "Not found."
    acc = account_selectors.get_account(account_id)
    if request.method == "POST" and acc is not None:
        reason = request.POST.get("reason", "").strip()
        if not reason:
            msg = "A reason is required."
        else:
            n = account_services.revoke_all_sessions(account=acc)
            audit.record(
                actor_type="staff",
                actor_id=request.staff.id,
                role=policies.primary_role(request.staff, "user.revoke_sessions"),
                action="support.revoke_sessions",
                target_type="account",
                target_id=acc.id,
                reason=reason,
                metadata={"count": str(n)},
                ip=client_ip(request),
            )
            msg = f"Signed out {n} session(s)."
    return _page(request, "users.html", q=str(account_id), found=None, ent=None, ver=None, msg=msg)


# ------------------------------------------------------------------------------------------------ verification
@staff_required("verification.queue")
def verification_queue(request: StaffRequest) -> HttpResponse:
    msg = ""
    if request.method == "POST":
        aid, action = _uuid(request.POST.get("attempt", "")), request.POST.get("action", "")
        who = _who(request, "verification.decide")
        if aid and action == "claim":
            msg = _run(request, lambda: review.claim(attempt_id=aid, **who), "Claimed.")
        elif aid and action in ("approve", "reject"):
            if not policies.can(request.staff, "verification.decide"):
                return HttpResponse(status=403)
            if not auth.recently_reauthed(request.staff_session):
                return redirect(f"/stepup?next={request.path}")
            msg = _run(
                request,
                lambda: review.decide_review(
                    attempt_id=aid,
                    approve=action == "approve",
                    reason=request.POST.get("reason", ""),
                    **who,
                ),
                "Decision saved.",
            )
    rows = review.queue(**_who(request, "verification.queue"))
    now = timezone.now()
    for row in rows:
        row["sla"] = dashboards.sla_badge(row["due_at"], now=now)  # type: ignore[arg-type]
    summary = dashboards.queue_summary([r["due_at"] for r in rows], now=now)  # type: ignore[misc]
    return _page(request, "verification.html", rows=rows, summary=summary, msg=msg)


# ------------------------------------------------------------------------------------------------ safety
@staff_required("safety.queue")
def safety_queue(request: StaffRequest) -> HttpResponse:
    now = timezone.now()
    cases = [
        {
            "id": c.id,
            "severity": c.severity,
            "sla_due_at": c.sla_due_at,
            "sla": dashboards.sla_badge(c.sla_due_at, now=now),
        }
        for c in safety_selectors.open_cases()[:200]
    ]
    summary = dashboards.queue_summary([c["sla_due_at"] for c in cases], now=now)
    return _page(request, "safety.html", cases=cases, summary=summary)


@staff_required("safety.evidence")
def safety_case(request: StaffRequest, case_id: uuid.UUID) -> HttpResponse:
    detail = safety_selectors.case_detail(case_id)
    if detail is None:
        return HttpResponse(status=404)
    audit.record(
        actor_type="staff",
        actor_id=request.staff.id,
        role=policies.primary_role(request.staff, "safety.evidence"),
        action="admin.view_evidence",
        target_type="case",
        target_id=case_id,
        reason="case review",
        ip=client_ip(request),
    )
    return _page(request, "case.html", detail=detail, kinds=ACTION_KINDS, msg="")


@staff_required("safety.act")
def safety_act(request: StaffRequest, case_id: uuid.UUID) -> HttpResponse:
    detail = safety_selectors.case_detail(case_id)
    if detail is None or request.method != "POST":
        return HttpResponse(status=404 if detail is None else 405)
    who = _who(request, "safety.act")
    msg = _run(
        request,
        lambda: enforcement.take_action(
            subject_id=detail["subject_id"], kind=request.POST.get("kind", ""), actor_id=who["actor_id"], actor_role=who["role"],  # type: ignore[arg-type]
            reason=request.POST.get("reason", ""), case_id=case_id, close_case=request.POST.get("close") == "1",
        ),
        "Action applied.",
    )  # fmt: skip
    return _page(
        request,
        "case.html",
        detail=safety_selectors.case_detail(case_id),
        kinds=ACTION_KINDS,
        msg=msg,
    )


# ------------------------------------------------------------------------------------------------ payments
@staff_required("payments.status")
def payments(request: StaffRequest) -> HttpResponse:
    uid, rows = _uuid(request.GET.get("account", "")), []
    if uid:
        rows = list(
            admin_ops.purchases_for_account(account_id=uid, **_who(request, "payments.status"))
        )
    return _page(
        request, "payments.html", rows=rows, account=request.GET.get("account", ""), msg=""
    )


@staff_required("payments.refund")
def refund(request: StaffRequest, purchase_id: uuid.UUID) -> HttpResponse:
    if request.method != "POST":
        return redirect("admin-payments")
    msg = _run(
        request,
        lambda: admin_ops.refund_web_purchase(
            purchase_id=purchase_id,
            reason=request.POST.get("reason", ""),
            **_who(request, "payments.refund"),
        ),
        "Refunded.",
    )
    return _page(request, "payments.html", rows=[], account="", msg=msg)


# ------------------------------------------------------------------------------------------------ privacy & audit
@staff_required("privacy.requests")
def privacy_requests(request: StaffRequest) -> HttpResponse:
    msg = ""
    if request.method == "POST":
        aid = _uuid(request.POST.get("account", ""))
        if aid and policies.can(request.staff, "privacy.cancel_deletion"):
            if not auth.recently_reauthed(request.staff_session):
                return redirect(f"/stepup?next={request.path}")
            msg = _run(
                request,
                lambda: privacy_services.cancel_deletion(
                    account_id=aid, **_who(request, "privacy.cancel_deletion")
                ),
                "Deletion cancelled.",
            )
    return _page(
        request,
        "privacy.html",
        rows=list(privacy_selectors.open_deletion_requests()[:200]),
        msg=msg,
    )


@staff_required("audit.all")
def audit_search(request: StaffRequest) -> HttpResponse:
    rows = audit_selectors.search(
        target_id=_uuid(request.GET.get("target", "")), action=request.GET.get("action") or None
    )[:200]
    return _page(request, "audit.html", rows=rows)


@staff_required("user.add_note")
def add_note(request: StaffRequest, account_id: uuid.UUID) -> HttpResponse:
    if request.method != "POST" or account_selectors.get_account(account_id) is None:
        return HttpResponse(status=404)
    who = _who(request, "user.add_note")
    msg = _run(
        request,
        lambda: services.add_note(
            account_id=account_id,
            staff_id=who["actor_id"],
            role=who["role"],
            body=request.POST.get("body", ""),
        ),
        "Note saved.",
    )
    return _page(
        request, "users.html", q=str(account_id), found=None, ent=None, ver=None, msg=msg, notes=[]
    )


# ------------------------------------------------------------------------------------------------ dashboards (Bible §15)
@staff_required("dashboard.funnel")
def funnel_dashboard(request: StaffRequest) -> HttpResponse:
    rng = dashboards.parse_range(
        request.GET.get("from", ""), request.GET.get("to", ""), now=timezone.now()
    )
    return _page(
        request,
        "funnel.html",
        rng=rng,
        rows=dashboards.funnel(rng),
        app_rows=dashboards.app_funnel(rng),
        min_cell=aggregates.label(None),
        msg=rng.error,
    )


@staff_required("dashboard.density")
def density_dashboard(request: StaffRequest) -> HttpResponse:
    rows = profile_selectors.live_density_by_district()
    for row in rows:
        row["text"] = aggregates.label(row["live"])  # type: ignore[arg-type]
    shown = [r for r in rows if r["live"] is not None]
    return _page(
        request,
        "density.html",
        rows=rows,
        shown_total=sum(r["live"] for r in shown),
        hidden_cells=len(rows) - len(shown),
        min_cell=aggregates.label(None),
    )


@staff_required("payments.reconciliation")
def reconciliation(request: StaffRequest) -> HttpResponse:
    overview = admin_ops.reconciliation_overview(**_who(request, "payments.reconciliation"))
    return _page(request, "reconciliation.html", **overview, msg="")


# ------------------------------------------------------------------------------------------------ feature flags
@staff_required("config.flags")
def flags(request: StaffRequest) -> HttpResponse:
    msg = ""
    if request.method == "POST":
        if not auth.recently_reauthed(request.staff_session):
            return redirect(f"/stepup?next={request.path}")
        enabled = {"on": True, "off": False}.get(request.POST.get("value", ""))
        if enabled is None:
            msg = "Choose on or off."
        else:
            changed: list[bool] = []

            def change() -> None:
                _, did = flag_services.set_flag(
                    key=request.POST.get("key", ""), enabled=enabled, reason=request.POST.get("reason", ""),
                    ip=client_ip(request), staff_id=request.staff.id, role=policies.primary_role(request.staff, "config.flags"),
                )  # fmt: skip
                changed.append(did)

            msg = _run(request, change, "Saved.")
            if msg == "Saved." and changed == [False]:
                msg = "No change: the flag already has that value."
    return _page(request, "flags.html", rows=flag_selectors.all_flags(), msg=msg)

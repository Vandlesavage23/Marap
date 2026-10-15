"""Server-rendered web checkout on the pay host (MC-100, Bible §11.3). Thin: every rule lives in accounts/billing."""

import uuid
from collections.abc import Callable
from typing import Any

from django.http import HttpRequest, HttpResponse
from django.shortcuts import redirect, render
from django.views.decorators.csrf import csrf_protect

from mc.accounts import phone as phone_lib
from mc.accounts import selectors as account_selectors
from mc.accounts import services as account_services
from mc.billing import selectors as billing_selectors
from mc.billing import web as billing_web
from mc.common.errors import DomainError
from mc.common.net import client_ip
from mc.common.redis import get_redis
from mc.entitlements import selectors as entitlement_selectors

from . import session

PHONE_COOKIE = "mc_pay_phone"


def _render(request: HttpRequest, template: str, status: int = 200, **ctx: Any) -> HttpResponse:
    return render(request, f"webcheckout/{template}", ctx, status=status)


def member_required(view: Callable[..., HttpResponse]) -> Callable[..., HttpResponse]:
    def inner(request: HttpRequest, *args: Any, **kwargs: Any) -> HttpResponse:
        account, fresh = session.resolve(request)
        if account is None:
            return redirect("pay-login")
        request.account = account  # type: ignore[attr-defined]
        response = view(request, *args, **kwargs)
        if fresh:
            session.set_tokens(response, access=fresh[0], refresh=fresh[1])
        return response

    return csrf_protect(inner)


@csrf_protect
def login(request: HttpRequest) -> HttpResponse:
    if request.method == "POST":
        raw = request.POST.get("phone", "")
        try:
            e164 = phone_lib.normalise(raw)
            # Members only: unknown numbers get the same page but no code is sent (no account enumeration).
            if account_selectors.get_account_by_phone(e164) is not None:
                account_services.start_otp(phone=e164, purpose="login", ip=client_ip(request))
        except DomainError as exc:
            return _render(request, "login.html", 422, error=exc.detail)
        resp = redirect("pay-code")
        resp.set_cookie(PHONE_COOKIE, e164, max_age=600, httponly=True, samesite="Strict")
        return resp
    return _render(request, "login.html")


@csrf_protect
def code(request: HttpRequest) -> HttpResponse:
    phone = request.COOKIES.get(PHONE_COOKIE, "")
    if not phone:
        return redirect("pay-login")
    if request.method == "POST":
        try:
            res = account_services.verify_otp(
                phone=phone, code=request.POST.get("code", "").strip(), ip=client_ip(request)
            )
        except DomainError as exc:
            return _render(request, "code.html", 422, error=exc.detail)
        resp = redirect("pay-products")
        session.set_tokens(resp, access=res.access, refresh=res.refresh)
        resp.delete_cookie(PHONE_COOKIE)
        return resp
    return _render(request, "code.html")


@member_required
def logout(request: HttpRequest) -> HttpResponse:
    resp = redirect("pay-login")
    session.clear(resp)
    return resp


@member_required
def products(request: HttpRequest) -> HttpResponse:
    ent = entitlement_selectors.entitlement_summary(request.account)  # type: ignore[attr-defined]
    return _render(
        request,
        "products.html",
        items=billing_selectors.active_products(platform="web"),
        ends=ent.membership_ends_at,
    )


@member_required
def pay(request: HttpRequest, code: str) -> HttpResponse:
    product = billing_selectors.get_product(code)
    if product is None or not product.web_enabled or not product.active:
        return _render(request, "error.html", 404, error="That plan isn't available.")
    if request.method == "POST":
        nonce = request.POST.get("nonce", "")
        if not (8 <= len(nonce) <= 64 and nonce.isalnum()):
            return _render(request, "error.html", 422, error="Please try again.")
        key = f"webpay:{request.account.id}:{nonce}"  # type: ignore[attr-defined]
        r = get_redis()
        existing = r.get(key)
        if existing:  # double-click / refresh: same purchase, no second charge
            return redirect(
                "pay-status",
                purchase_id=existing.decode() if isinstance(existing, bytes) else str(existing),
            )
        try:
            purchase, _ = billing_web.start_checkout(
                account=request.account, product_code=code, method=request.POST.get("method", ""),  # type: ignore[attr-defined]
                phone=request.POST.get("phone", ""), network=request.POST.get("network", ""),
            )  # fmt: skip
        except DomainError as exc:
            return _render(request, "pay.html", 422, product=product, nonce=nonce, error=exc.detail)
        r.set(key, str(purchase.id), ex=3600)
        return redirect("pay-status", purchase_id=purchase.id)
    return _render(request, "pay.html", product=product, nonce=uuid.uuid4().hex)


@member_required
def status(request: HttpRequest, purchase_id: uuid.UUID) -> HttpResponse:
    p = billing_web.purchase_status(account=request.account, purchase_id=purchase_id)  # type: ignore[attr-defined]
    if p is None:
        return _render(request, "error.html", 404, error="We couldn't find that payment.")
    state = {"pending": "pending", "active": "paid"}.get(p.status, "failed")
    return _render(request, "status.html", p=p, state=state)

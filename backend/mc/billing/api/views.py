import json
from typing import Any

from django.utils import timezone
from drf_spectacular.utils import extend_schema
from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.utils.encoders import JSONEncoder
from rest_framework.views import APIView

from mc.accounts.permissions import IsActiveMember
from mc.common.errors import ValidationFailed
from mc.common.idempotency import IdempotentMixin
from mc.common.serializers import reject_unknown_fields
from mc.entitlements import selectors as entitlement_selectors

from .. import selectors, store, web
from ..providers import google
from . import serializers as s


def _entitlements(account) -> dict[str, Any]:  # type: ignore[no-untyped-def]
    now = timezone.now()
    st = entitlement_selectors.entitlement_summary(account, now)
    return json.loads(
        json.dumps(
            {
                "state": st.state,
                "membership": {"ends_at": st.membership_ends_at, "source": st.membership_source}
                if st.membership_ends_at
                else None,
                "capabilities": st.capabilities,
                "server_time": now,
            },
            cls=JSONEncoder,
        )
    )


class ProductsView(APIView):
    permission_classes = [IsActiveMember]

    @extend_schema(responses={200: dict})
    def get(self, request):  # type: ignore[no-untyped-def]
        platform = request.query_params.get("platform", "")
        if platform not in ("ios", "android"):
            raise ValidationFailed("platform must be 'ios' or 'android'.")
        items = [
            {
                "code": p.code,
                "duration_days": p.duration_days,
                "price_minor": p.price_minor,
                "currency": p.currency,
                "store_product_id": p.apple_product_id
                if platform == "ios"
                else p.google_product_id,
            }
            for p in selectors.active_products(platform=platform)
        ]
        return Response({"items": items, "next_cursor": None})


class StoreVerifyView(IdempotentMixin):
    permission_classes = [IsActiveMember]

    @extend_schema(request=s.StoreVerifySerializer, responses={200: dict})
    def perform_idempotent(self, request):  # type: ignore[no-untyped-def]
        data = s.StoreVerifySerializer(data=request.data)
        reject_unknown_fields(data, request.data)
        data.is_valid(raise_exception=True)
        v = data.validated_data
        if v["platform"] == "ios":
            store.verify_apple_transaction(
                account=request.user, signed_transaction=v["signed_transaction"]
            )
        else:
            store.verify_google_purchase(
                account=request.user, product_id=v["product_id"], purchase_token=v["purchase_token"]
            )
        return status.HTTP_200_OK, _entitlements(request.user)


class AppleWebhookView(APIView):
    permission_classes = [AllowAny]
    authentication_classes: list = []

    @extend_schema(request=None, responses={200: dict}, auth=[])
    def post(self, request):  # type: ignore[no-untyped-def]
        signed = request.data.get("signedPayload") if isinstance(request.data, dict) else None
        if not isinstance(signed, str):
            raise ValidationFailed("signedPayload is required.")
        store.handle_apple_notification(signed_payload=signed)
        return Response({"status": "ok"})


class GoogleWebhookView(APIView):
    permission_classes = [AllowAny]
    authentication_classes: list = []

    @extend_schema(request=None, responses={200: dict}, auth=[])
    def post(self, request):  # type: ignore[no-untyped-def]
        google.verify_pubsub_oidc(request.headers.get("Authorization", ""))
        message_id, payload = google.decode_envelope(
            request.data if isinstance(request.data, dict) else {}
        )
        store.handle_google_rtdn(message_id=message_id, payload=payload)
        return Response({"status": "ok"})


class WebProductsView(APIView):
    permission_classes = [IsActiveMember]

    @extend_schema(responses={200: dict})
    def get(self, request):  # type: ignore[no-untyped-def]
        items = [
            {
                "code": p.code,
                "duration_days": p.duration_days,
                "price_minor": p.price_minor,
                "currency": p.currency,
            }
            for p in selectors.active_products(platform="web")
        ]
        return Response({"items": items, "next_cursor": None})


class WebCheckoutView(IdempotentMixin):
    """Served on the pay host (pay.<domain>) by the web checkout pages; same API surface, member token auth."""

    permission_classes = [IsActiveMember]

    @extend_schema(request=s.CheckoutSerializer, responses={201: dict})
    def perform_idempotent(self, request):  # type: ignore[no-untyped-def]
        data = s.CheckoutSerializer(data=request.data)
        reject_unknown_fields(data, request.data)
        data.is_valid(raise_exception=True)
        v = data.validated_data
        purchase, next_step = web.start_checkout(
            account=request.user,
            product_code=v["product_code"],
            method=v["method"],
            phone=v["phone"],
            network=v["network"],
        )
        return status.HTTP_201_CREATED, {
            "purchase_id": str(purchase.id),
            "status": purchase.status,
            "amount_minor": purchase.amount_minor,
            "currency": purchase.currency,
            **next_step,
        }


class WebPurchaseView(APIView):
    permission_classes = [IsActiveMember]

    @extend_schema(responses={200: dict})
    def get(self, request, purchase_id):  # type: ignore[no-untyped-def]
        from mc.common.errors import NotFound

        p = web.purchase_status(account=request.user, purchase_id=purchase_id)
        if p is None:
            raise NotFound()
        return Response(
            json.loads(
                json.dumps(
                    {
                        "purchase_id": str(p.id),
                        "status": p.status,
                        "period_end": p.period_end,
                        "product": p.product.code,
                    },
                    cls=JSONEncoder,
                )
            )
        )


class FlutterwaveWebhookView(APIView):
    permission_classes = [AllowAny]
    authentication_classes: list = []

    @extend_schema(request=None, responses={200: dict}, auth=[])
    def post(self, request):  # type: ignore[no-untyped-def]
        web.handle_flutterwave_webhook(
            verif_hash=request.headers.get("verif-hash", ""),
            payload=request.data if isinstance(request.data, dict) else {},
        )
        return Response({"status": "ok"})

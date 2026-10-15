"""Flutterwave (mobile money + cards) behind a gateway interface (Bible §11.3).

Rule: a webhook is only a *hint*. We never grant from its body; we re-fetch the transaction from Flutterwave
and check status, amount, currency and tx_ref against OUR purchase record before granting.

STATUS: `FlutterwaveGateway` is written from public docs and NOT yet run against the sandbox (MC-003)."""

import json
import urllib.error
import urllib.request
from dataclasses import dataclass
from typing import Any, ClassVar, Protocol

from django.conf import settings
from django.utils.module_loading import import_string

from mc.common.errors import ProviderError


@dataclass(frozen=True)
class Charge:
    link: str = ""  # hosted checkout (cards)
    pending_instruction: str = ""  # e.g. "Approve the prompt on your phone"
    provider_ref: str = ""


@dataclass(frozen=True)
class VerifiedTransaction:
    transaction_id: str
    tx_ref: str
    status: str  # successful | failed | pending
    amount: int  # minor units (UGX: whole shillings)
    currency: str


class PaymentGateway(Protocol):
    def create_charge(
        self, *, tx_ref: str, amount: int, currency: str, method: str, phone: str, network: str
    ) -> Charge: ...

    def verify_transaction(self, transaction_id: str) -> VerifiedTransaction: ...

    def verify_by_reference(self, tx_ref: str) -> VerifiedTransaction | None: ...

    def refund(self, *, transaction_id: str, amount: int) -> str: ...


class FakeGateway:
    """Scriptable: tests put transactions in `transactions` keyed by id; `charges` records create_charge calls."""

    transactions: ClassVar[dict[str, VerifiedTransaction]] = {}
    charges: ClassVar[list[dict[str, Any]]] = []
    refunds: ClassVar[list[tuple[str, int]]] = []
    fail: ClassVar[bool] = False

    def create_charge(
        self, *, tx_ref: str, amount: int, currency: str, method: str, phone: str, network: str
    ) -> Charge:
        if FakeGateway.fail:
            raise ProviderError("gateway unavailable")
        FakeGateway.charges.append(
            {
                "tx_ref": tx_ref,
                "amount": amount,
                "currency": currency,
                "method": method,
                "network": network,
            }
        )
        if method == "card":
            return Charge(link=f"https://checkout.fake/{tx_ref}", provider_ref=tx_ref)
        return Charge(pending_instruction="Approve the prompt on your phone", provider_ref=tx_ref)

    def verify_transaction(self, transaction_id: str) -> VerifiedTransaction:
        if FakeGateway.fail:
            raise ProviderError("gateway unavailable")
        try:
            return FakeGateway.transactions[transaction_id]
        except KeyError as exc:
            raise ProviderError("unknown transaction") from exc

    def verify_by_reference(self, tx_ref: str) -> VerifiedTransaction | None:
        if FakeGateway.fail:
            raise ProviderError("gateway unavailable")
        return next((t for t in FakeGateway.transactions.values() if t.tx_ref == tx_ref), None)

    def refund(self, *, transaction_id: str, amount: int) -> str:
        if FakeGateway.fail:
            raise ProviderError("gateway unavailable")
        FakeGateway.refunds.append((transaction_id, amount))
        return f"refund-{transaction_id}"

    @classmethod
    def reset(cls) -> None:
        cls.transactions.clear()
        cls.charges.clear()
        cls.refunds.clear()
        cls.fail = False


class FlutterwaveGateway:  # pragma: no cover - needs Flutterwave
    base = "https://api.flutterwave.com/v3"

    def _call(self, method: str, path: str, body: dict[str, Any] | None = None) -> dict[str, Any]:
        req = urllib.request.Request(
            f"{self.base}{path}", method=method, data=json.dumps(body).encode() if body is not None else None,
            headers={"Authorization": f"Bearer {settings.FLUTTERWAVE_SECRET_KEY}", "Content-Type": "application/json"},
        )  # fmt: skip
        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                return json.loads(resp.read())
        except (urllib.error.URLError, ValueError) as exc:
            raise ProviderError("payment provider error") from exc

    def create_charge(
        self, *, tx_ref: str, amount: int, currency: str, method: str, phone: str, network: str
    ) -> Charge:
        if method == "card":
            data = self._call("POST", "/payments", {
                "tx_ref": tx_ref, "amount": amount, "currency": currency, "redirect_url": settings.CHECKOUT_REDIRECT_URL,
                "payment_options": "card", "customer": {"phone_number": phone, "email": "member@marriageconnect.ug"},
            })  # fmt: skip
            return Charge(link=data["data"]["link"], provider_ref=tx_ref)
        data = self._call("POST", "/charges?type=mobile_money_uganda", {
            "tx_ref": tx_ref, "amount": amount, "currency": currency, "phone_number": phone, "network": network.upper(),
            "email": "member@marriageconnect.ug",
        })  # fmt: skip
        if data.get("status") != "success":
            raise ProviderError("mobile money charge was not accepted")
        return Charge(pending_instruction="Approve the prompt on your phone", provider_ref=tx_ref)

    @staticmethod
    def _tx(d: dict[str, Any]) -> VerifiedTransaction:
        return VerifiedTransaction(
            str(d["id"]),
            str(d["tx_ref"]),
            str(d["status"]),
            int(float(d["amount"])),
            str(d["currency"]),
        )

    def verify_transaction(self, transaction_id: str) -> VerifiedTransaction:
        return self._tx(self._call("GET", f"/transactions/{transaction_id}/verify")["data"])

    def verify_by_reference(self, tx_ref: str) -> VerifiedTransaction | None:
        data = self._call("GET", f"/transactions/verify_by_reference?tx_ref={tx_ref}")
        return self._tx(data["data"]) if data.get("data") else None

    def refund(self, *, transaction_id: str, amount: int) -> str:
        data = self._call("POST", f"/transactions/{transaction_id}/refund", {"amount": amount})
        return str(data["data"]["id"])


def get_gateway() -> PaymentGateway:
    return import_string(settings.PAYMENT_GATEWAY)()

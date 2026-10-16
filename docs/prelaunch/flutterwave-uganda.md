# MC-003: Flutterwave Uganda merchant onboarding

> **STATUS: research only — not a decision / not completed.** No account was opened. Flutterwave's own docs domain could not be fetched here; findings are from web-search summaries on 2026-10-16. Fees below are NOT verified and sources conflict.

**Owner:** finance/ops lead (needs company registration documents); tech lead for sandbox/webhook testing.

## 1. What public sources say
- Official docs: collections in UGX via mobile money MTN or Airtel; request needs customer phone_number and network ("MTN" or "AIRTEL"), amount, currency, email and a unique tx_ref; the customer approves the prompt on their phone (https://developer.flutterwave.com/docs/uganda).
- Business requirements: the backlog says a company registration is needed. One Kampala blog (https://kolonell.com/en/blog/mtn-momo-vs-airtel-money-merchant-fees-uganda-2026) says KYC requires ID plus business registration; this is a blog, **not Flutterwave**. Official document list not seen.
- Fees: third-party figures conflict: about 1.4% (one blog), about 1-1.5% (another blog), and aggregators generally cost more than direct MTN/Airtel integrations (https://mctaba.com/learn/uganda/flutterwave-vs-easypay-vs-momo-api-uganda). **No official Flutterwave figure was found. Do not budget from these.**
- Webhooks: Flutterwave sends your configured secret hash in the `verif-hash` header; you compare with your stored copy (plain equality, not HMAC) (https://dev.to/flutterwaveeng/what-are-webhooks-and-how-do-you-implement-them-15j4). Treat the webhook as a trigger and re-verify with `GET /v3/transactions/{id}/verify` checking status, amount, currency (and tx_ref). Retry behaviour: sources disagree (3 retries 30 min apart vs about 5 over about 24 h); both non-official.
- Bible 11.3 matches this shape (verif-hash, then re-verify `GET /transactions/{id}/verify`).

## 2. Steps for a human
1. Gather: certificate of incorporation, TIN, directors' IDs, proof of address, bank account details, website/product description, store listings (ask Flutterwave for the exact list).
2. Register at the Flutterwave dashboard, choose Uganda, submit KYC; record the date and reference.
3. Obtain test keys (sandbox) and, after approval, live keys; store in secrets manager only (CLAUDE.md rule 2).
4. Set the webhook URL and secret hash in the dashboard for dev and prod separately.

## 3. Questions to put to Flutterwave in writing
**Commercial**
- Written fee schedule per method: MTN mobile money, Airtel Money, card (if offered in Uganda), payout/settlement fees, refund fees, chargeback/reversal fees, VAT/excise, FX if settled in USD.
- Settlement currency (UGX?), settlement timing (T+?), rolling reserves, minimum balances, payout bank requirements.
- Transaction limits per customer/day (mobile money caps), minimum amounts for our membership prices, failed-payment handling.
- Is the account contractually tied to the Ugandan company entity? Is a foreign company eligible?

**Technical**
- Sandbox: test MTN/Airtel numbers and OTP/approval simulation for success, failure, pending, timeout, wrong PIN, insufficient funds.
- Direct mobile-money charge vs Standard hosted checkout: which is recommended for UGX; what does the redirect/`flw_ref` look like; `tx_ref` uniqueness rules (we use purchase id).
- Webhook: exact header(s) (`verif-hash` only, or is there a newer signature header in the current API version?), events sent for mobile money (charge.completed, transfer.*, refund?), retry schedule, timeout expected from our endpoint, source IPs to allowlist, whether the webhook can arrive before our DB row commits.
- Verify endpoint: current path and version, field names (`status`, `amount`, `currency`, `tx_ref`, `charged_amount`, `app_fee`), behaviour for pending/expired.
- Refund API support for Uganda mobile money; partial refunds (Bible 11.3 proportional refunds, PENDING counsel); timing.
- Transaction list API for nightly reconciliation (pagination, date filters, rate limits).
- Does Flutterwave offer a pay-by-phone-number without email (our members sign in with phone; the API needs an email field)? What placeholder is acceptable (no real emails, CLAUDE.md privacy rules)?
- Data: what customer data is stored, retention, DPA, cross-border transfer, Flutterwave's registration with Uganda's PDPO.
- Status/uptime page, support SLA, escalation contacts.

## 4. Exit criteria for MC-003
Account approved; sandbox keys received; written fee schedule filed; webhook sample payloads captured and compared to `docs/BUILD_BIBLE.md` 11.3 and the billing module's parser; refund and reconciliation approach confirmed.

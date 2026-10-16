# MC-006: SMS OTP provider and sender ID (Uganda)

> **STATUS: research only — not a decision / not completed.** No provider account exists, no sender ID was registered, no message was sent. Information is from third-party aggregator pages and web-search summaries on 2026-10-16; no primary UCC (Uganda Communications Commission) document and no Africa's Talking Uganda rate card was found. Costs are UNKNOWN.

**Owner:** ops lead (registrations, contracts); tech lead (configuration).

## 1. What sources say
- Sender IDs: registration is reported as required (with UCC and/or the operators) for alphanumeric sender IDs in Uganda; MTN is the strictest and overwrites or fails unregistered alphanumeric IDs (https://support.telnyx.com/en/articles/6683433-uganda-sms-guidelines; https://docs.linkmobility.com/regulatory-guidelines/sender-id/uganda; https://www.plivo.com/sms/coverage/ug/).
- Numeric/long-code sender IDs are reported as unsupported by MTN, Airtel, Africell and Smart (https://www.twilio.com/en-us/guidelines/ug/sms).
- Documents reported: sender ID name, content samples, company details, VAT/registration, traffic type (Link Mobility); use case, expected monthly volume, company details, and a Letter of Authorization (Infobip: https://www.infobip.com/docs/essentials/africa-registration/uganda-letter-of-authorization-loa-guidelines). Infobip reportedly says MTN expects at least 1K monthly traffic and removes sender IDs that fall below it. These are provider requirements, not UCC rules.
- Timing: "about 3 weeks" for alphanumeric registration (https://sent.dm/en/resources/sms-compliance/ug-sms-guidance, secondary). Africa's Talking: sender ID requested per country from the dashboard, with a company-letterhead letter and sample messages, "2 to 5 business days" per a developer guide that may describe Kenya rather than Uganda (https://helloduty.com/blogs/sending-bulk-sms-via-africas-talking-api). Treat both timings as unverified.
- Prices: Africa's Talking Uganda rates NOT found. A pricing comparison lists about USD 0.11-0.26 per SMS for Plivo, Sinch, Infobip, Twilio to Uganda (https://www.sent.dm/resources/uganda-sms-pricing, secondary, unverified). Do not budget from this; get quotes.

## 2. Provider options (none evaluated beyond the above)
| Option | Notes |
| --- | --- |
| Africa's Talking | Current default in code (`AfricasTalkingSms`, Bible 11.4 "(A)"). Local rates, sender-ID process, delivery reports, and sandbox to be confirmed. |
| Twilio | Named as fallback in the Bible; **`TwilioSms` does not exist in the code yet** (grep: only the Bible mentions it). Would need a new adapter. Pricing/registration to confirm. |
| Infobip, Sinch, Plivo, others | Mentioned by sources; not evaluated. |
| Direct operator bulk SMS (MTN/Airtel Uganda) | Not researched. |
| Alternatives to SMS OTP (WhatsApp, voice, silent verification) | Out of scope for MC-006; note SMS pumping risk (Q29, runbook `docs/runbooks/otp-spike.md`). |

## 3. Questions to ask each provider (written)
- Per-SMS price to MTN, Airtel, Africell, and others in UGX/USD; minimum top-ups; volume tiers; failed-SMS billing.
- Alphanumeric sender ID: exact documents, timeline, who registers (provider vs us), who pays, whether UCC registration is required and how, renewal, per-operator rules, minimum monthly traffic; fallback behaviour if not registered (generic ID?).
- Delivery receipts and latency to Ugandan numbers; OTP-specific routes; DND; throughput limits; anti-fraud/SMS pumping protections and geo-permissions.
- Message content restrictions (OTP template pre-approval).
- Data processing agreement; message retention (OTP bodies contain codes; CLAUDE.md rule 10 says never log them); where data is processed; PDPO registration.
- Sandbox availability and test numbers.

## 4. Steps for a human
1. Choose 1-2 providers and request quotes.
2. Create the account under the company entity; complete KYC.
3. Submit the sender ID application (draft names, e.g. a short brand name; avoid generic words) with sample OTP text. Draft sample text for the template: one line in English, no links, no personal data, e.g. "<code> is your Marriage Connect code" (final wording is a product/legal decision).
4. After approval, record in the secrets store: username, API key, sender ID.
5. Test on real MTN, Airtel and Africell numbers (delivery time, sender display).
6. Confirm the spend alert and the `OTP_SPIKE_ALERT_PER_HOUR` setting.

## 5. Backend configuration (existing code, `backend/mc/accounts/providers/sms.py`)
- `SMS_PROVIDER` is a dotted path to the provider class. Base default is `mc.accounts.providers.sms.FakeSms`; `config/settings/prod.py` requires it explicitly (never the fake in prod). For Africa's Talking set `SMS_PROVIDER=mc.accounts.providers.sms.AfricasTalkingSms`.
- `AfricasTalkingSms` reads `AT_USERNAME`, `AT_API_KEY`, `AT_SENDER_ID` (see `backend/config/settings/base.py` lines about 167-171), posts to `https://api.africastalking.com/version1/messaging`, and passes `from` only if `AT_SENDER_ID` is non-empty. It treats statusCode 100, 101 or 102 as success and otherwise raises `ProviderError`. Leave `AT_SENDER_ID` empty until the sender ID is approved, otherwise messages may be dropped or relabelled.
- Africa's Talking's sandbox typically uses the username `sandbox` with a separate sandbox API key **[verify in its docs]**; the endpoint for sandbox is a different host **[verify]**: the code hard-codes the live URL, so a sandbox test needs a settings override or a small code change (a ticket, not part of MC-006).
- Secrets go in AWS Secrets Manager injected as env at task start (Bible 3.3); never in the repo or the app.
- Adding another provider: implement `send(self, *, to_e164, body)` with the same `ProviderError` semantics and set `SMS_PROVIDER`; add tests with `FakeSms` unchanged. OTP bodies must never be logged.
- Reviewer sign-in (Q26) bypasses SMS by design; do not use it for real users.

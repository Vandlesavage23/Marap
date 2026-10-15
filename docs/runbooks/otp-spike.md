# SMS-pumping / OTP spike (`alert=otp_send_spike`)
Raised once per hour when global OTP sends cross `OTP_SPIKE_ALERT_PER_HOUR` (default 1000).
1. Check the SMS provider dashboard for destinations: a burst to one country/prefix you don't serve, or to premium ranges, is fraud.
2. Existing guards already cap per phone (5/h), per IP (20/h) and per prefix (300/h); tighten `OTP_SENDS_PER_PREFIX_PER_HOUR`
   or reduce `OTP_ALLOWED_CALLING_CODES` (default `256` only) and redeploy config — no code change needed.
3. If a prefix is being abused, block it at the WAF rate rule and ask the provider to block the destination range.
4. Verify: sends/hour back to baseline; no unexpected spend; the alert did not re-fire.
5. Follow-up: review whether the provider offers fraud-guard; record the incident.

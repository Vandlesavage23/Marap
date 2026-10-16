# Payment webhook failures (`alert=payment_webhook_failures`)
Raised by the beat task `mc.billing.tasks.check_webhook_failures` (every 5 minutes) when **more than 5**
`PaymentEvent` rows received in the last **10 minutes** are in `process_status=failed`
(`PAYMENT_WEBHOOK_FAILURE_THRESHOLD`, `PAYMENT_WEBHOOK_FAILURE_WINDOW_MINUTES`). The log carries `count`,
`window_minutes`, `threshold` and `by_provider` (apple/google/flutterwave). It does not count events rejected for a bad
signature (stored as `ignored`, `error=bad_signature`); look at those separately if you suspect a rotated secret.

Failed events mean members may have paid without receiving their entitlement.
1. Which provider (`by_provider`)? Check the provider status page and our `/webhooks/...` 5xx rate.
2. Inspect the failures in the admin payments view / DB: `SELECT provider, error, count(*) FROM billing_paymentevent
   WHERE process_status='failed' AND received_at > now() - interval '30 minutes' GROUP BY 1,2`. Common `error` codes:
   `unknown_product` (a store product id not mapped in `Product`), `account_unresolved` (retried automatically every
   10 minutes by `billing-retry-failed`), `account_mismatch`.
3. `unknown_product`: add/map the product, then re-queue the events (`retry_failed` handles only `account_unresolved`;
   set the rows back to `pending` and run `process_event` per event, it is idempotent).
4. A burst of `account_unresolved` after a deploy usually means the accounts table lags or the account id is missing
   from the provider payload; check the deploy and Redis/Postgres health.
5. Verify: failed count in the window is back to 0-5, affected members have an active entitlement, run the
   nightly reconciliation report (`billing.tasks.nightly_reconciliation`) and confirm no mismatches.
6. Follow-up: record the cause; add a regression test for the failing payload shape.

# Payments reconciliation mismatch (`alert=payments_reconciliation_mismatch`)
Never edit entitlements or ledger rows by hand (CLAUDE.md rule 7).
1. Admin portal → Payments (role `payments_ops`): look up the affected purchase ids from the nightly report log.
2. Compare with the provider dashboard (Flutterwave / App Store Connect / Play Console).
3. Re-drive: Flutterwave → `billing.sweep_pending_web` re-verifies against the gateway; Google → `reconcile_google`
   refreshes from the Play API; Apple → wait for the next server notification or ask the member to Restore purchases.
4. Refund needed? Use Payments → Refund (web only; step-up MFA required). Store refunds happen in the store.
5. Verify: ledger balance for the purchase equals charges − refunds; member's `/me/entitlements` is right.
6. Follow-up: if a webhook was dropped, check provider retry settings; if amounts differed, treat as possible fraud.

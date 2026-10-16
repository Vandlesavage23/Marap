# Runbooks

Each runbook: **symptom → check → act → verify → follow-up**. Alerts are structured WARNING log lines carrying an
`alert` field; the log pipeline (CloudWatch metric filters, MC-020/124) turns each into a page.

| `alert` value | Meaning | Runbook |
| --- | --- | --- |
| `s1_report` | A severity-1 safety report was created (threat, underage, …) | [safety-s1.md](safety-s1.md) |
| `payments_reconciliation_mismatch` | Nightly reconciliation found Purchases that disagree with the provider | [payments-reconciliation.md](payments-reconciliation.md) |
| `admin_access_denied` | A staff member tried something their role doesn't allow | [admin-access-denied.md](admin-access-denied.md) |
| `queue_age_high` | Oldest queued Celery task is older than 5 minutes (worker/Redis/poison task) | [queue-age.md](queue-age.md) |
| `payment_webhook_failures` | More than 5 payment events failed processing in 10 minutes | [payment-webhook-failures.md](payment-webhook-failures.md) |
| `otp_send_spike` | Global OTP sends crossed the hourly threshold (SMS pumping) | [otp-spike.md](otp-spike.md) |
| (alarm) ALB 5xx > 2% for 5 min, p95 target response time > 1 s for 10 min, DB CPU > 80% for 15 min | Capacity or dependency problem; check Sentry, `/metrics` route latency, RDS/Redis alarms | [outage.md](outage.md) |
| (health) `/ready` red, 5xx spike | Dependency outage | [outage.md](outage.md) |
| (manual) | Suspected account takeover | [account-takeover.md](account-takeover.md) |
| (manual) | Suspected personal-data incident | [data-incident.md](data-incident.md) |
| (manual) | Restore from backup / key rotation | [restore-and-keys.md](restore-and-keys.md) |

Game-day (MC-126 acceptance): trigger each alert once in staging, confirm the page arrives and the runbook works.
**Not done yet** — needs the staging environment (MC-124).

## Metrics and tracing (Bible §15)
* `GET /metrics` (Prometheus text) is served **only on the admin host** and needs `Authorization: Bearer <METRICS_TOKEN>`
  (a Secrets Manager entry). With `METRICS_TOKEN` unset the endpoint answers 403 (fails closed); a missing/wrong token is 401.
  The api and pay hosts return 404 for it. Point the scraper at `https://admin.<domain>/metrics`; the staff IP allowlist
  (`ADMIN_IP_ALLOWLIST`) still applies at the edge. Route labels are URL *patterns*, never ids or PII.
* Tracing is off unless `OTEL_EXPORTER_OTLP_ENDPOINT` is set (10% sampling by default, `OTEL_TRACES_SAMPLER_RATIO`);
  all span attributes are scrubbed of phone/email/body/token before export.

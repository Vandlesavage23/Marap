# Runbooks

Each runbook: **symptom → check → act → verify → follow-up**. Alerts are structured WARNING log lines carrying an
`alert` field; the log pipeline (CloudWatch metric filters, MC-020/124) turns each into a page.

| `alert` value | Meaning | Runbook |
| --- | --- | --- |
| `s1_report` | A severity-1 safety report was created (threat, underage, …) | [safety-s1.md](safety-s1.md) |
| `payments_reconciliation_mismatch` | Nightly reconciliation found Purchases that disagree with the provider | [payments-reconciliation.md](payments-reconciliation.md) |
| `admin_access_denied` | A staff member tried something their role doesn't allow | [admin-access-denied.md](admin-access-denied.md) |
| `otp_send_spike` | Global OTP sends crossed the hourly threshold (SMS pumping) | [otp-spike.md](otp-spike.md) |
| (health) `/ready` red, 5xx spike | Dependency outage | [outage.md](outage.md) |
| (manual) | Suspected personal-data incident | [data-incident.md](data-incident.md) |
| (manual) | Restore from backup / key rotation | [restore-and-keys.md](restore-and-keys.md) |

Game-day (MC-126 acceptance): trigger each alert once in staging, confirm the page arrives and the runbook works.
**Not done yet** — needs the staging environment (MC-124).

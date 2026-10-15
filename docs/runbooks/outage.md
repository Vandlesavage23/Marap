# Dependency outage (Postgres / Redis / vendor)
The API returns `503 service_unavailable` (`Retry-After: 5`) for Redis/Postgres failures and `502 provider_error` for vendor
failures; clients retry safely (idempotency keys). Nothing is half-written (transactions roll back) — scenario 14.
1. `/ready` and the dashboard show which dependency failed.
2. Postgres: fail over to the replica (Multi-AZ), confirm migrations state; Redis: restart/failover — rate limits and
   idempotency records reset (acceptable; DB unique constraints still prevent duplicates).
3. Vendors: Smile ID down → verification pending, no action; payments gateway down → web checkout shows an error and no purchase
   is created; push down → in-app inbox still works.
4. Verify: error rate back to baseline; Celery queues drained; `billing.retry_failed` ran.

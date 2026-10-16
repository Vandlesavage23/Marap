# Celery queue backed up (`alert=queue_age_high`)
Raised by the beat task `mc.common.tasks.queue_age_check` (every 60 s) when the **oldest waiting task** in any of the
queues `default`, `media`, `billing`, `notify` is older than `QUEUE_AGE_ALERT_SECONDS` (300 = 5 minutes). The WARNING log
carries `queue`, `depth`, `oldest_age_seconds` and `threshold_seconds` (no task arguments, no payloads). While the
condition lasts it re-fires every minute; the CloudWatch alarm collapses that into one page.

Age comes from an `mc_enqueued_at` header stamped on every published task. Depth/age are also on `/metrics`
(`mc_celery_queue_depth`, `mc_celery_queue_oldest_age_seconds`).

1. Which queue? `billing` = payments/entitlements delayed (members paid but not upgraded: treat as urgent, see
   [payments-reconciliation.md](payments-reconciliation.md)); `notify` = pushes/SMS late; `media` = photo/voice processing;
   `default` = everything else (also hosts this check, see below).
2. Is the worker alive? ECS service `worker` running count (alarm `ecs-running-tasks`), recent worker logs, OOM kills.
   Restart/scale the worker service if tasks are healthy but too few.
3. Is Redis healthy? Check the Redis alarms (CPU, memory, evictions) and `/ready`. An unreachable broker is an outage:
   follow [outage.md](outage.md).
4. Is one task poisoning the queue (same task failing/retrying, a vendor timing out)? Look for repeated errors in the worker
   log and Sentry; for a vendor outage see [outage.md](outage.md).
5. Scale `worker` tasks out if the backlog is just load. Do not purge a queue: tasks are idempotent but purging loses work.
6. Verify: oldest age back under 5 minutes, depth falling, alert stopped re-firing.
7. Follow-up: note the cause; adjust worker sizing/concurrency or add a queue-specific worker if one queue starves another.

Blind spot: the check itself runs through the `default` queue on the same workers. If every worker is dead no alert is
emitted by this task; the ECS running-task alarm and ALB/`/ready` alarms cover that case.

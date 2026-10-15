#!/usr/bin/env bash
# Run the one-off migration task (python manage.py migrate --noinput) and fail the step if it fails.
# Network configuration (subnets, security groups) is copied from the running api service.
# Usage: ecs-run-migrate.sh <env> <image>      (needs AWS_REGION and credentials in the environment)
set -euo pipefail

ENVIRONMENT="${1:?environment required}"
IMAGE="${2:?image required}"
PREFIX="mc-${ENVIRONMENT}"
CLUSTER="$PREFIX"
HERE="$(cd "$(dirname "$0")" && pwd)"

TASKDEF="$("$HERE/ecs-register-revision.sh" "${PREFIX}-migrate" "$IMAGE")"
echo "Migration task definition: $TASKDEF"

NETCONF="$(aws ecs describe-services --cluster "$CLUSTER" --services "${PREFIX}-api" \
  --query 'services[0].networkConfiguration' --output json)"
if [ -z "$NETCONF" ] || [ "$NETCONF" = "null" ]; then
  echo "Cannot read network configuration of ${PREFIX}-api" >&2
  exit 1
fi

TASK_ARN="$(aws ecs run-task --cluster "$CLUSTER" --launch-type FARGATE --task-definition "$TASKDEF" \
  --network-configuration "$NETCONF" --count 1 --started-by "github-actions-migrate" \
  --query 'tasks[0].taskArn' --output text)"
if [ -z "$TASK_ARN" ] || [ "$TASK_ARN" = "None" ]; then
  echo "run-task did not start a task" >&2
  exit 1
fi
echo "Started migration task: $TASK_ARN"

aws ecs wait tasks-stopped --cluster "$CLUSTER" --tasks "$TASK_ARN" || true

EXIT_CODE="$(aws ecs describe-tasks --cluster "$CLUSTER" --tasks "$TASK_ARN" \
  --query 'tasks[0].containers[?name==`migrate`].exitCode | [0]' --output text)"
REASON="$(aws ecs describe-tasks --cluster "$CLUSTER" --tasks "$TASK_ARN" \
  --query 'tasks[0].stoppedReason' --output text)"

# Show the tail of the migration log (migrations log table names, not user data).
TASK_ID="${TASK_ARN##*/}"
LOG_GROUP="/mc/${ENVIRONMENT}/migrate"
aws logs get-log-events --log-group-name "$LOG_GROUP" --log-stream-name "migrate/migrate/${TASK_ID}" \
  --limit 80 --query 'events[].message' --output text 2>/dev/null || echo "(no log events available)"

if [ "$EXIT_CODE" != "0" ]; then
  aws ecs stop-task --cluster "$CLUSTER" --task "$TASK_ARN" --reason "migration failed or timed out" >/dev/null 2>&1 || true
  echo "Migration failed: exitCode=${EXIT_CODE} reason=${REASON}" >&2
  exit 1
fi
echo "Migration succeeded."

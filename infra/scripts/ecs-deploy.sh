#!/usr/bin/env bash
# Rolling deploy of api, ws, worker and beat to <image>, with automatic rollback.
#   1. remember each service's current task definition
#   2. register a new revision per service (same config, new image) and update the service
#   3. wait for stability, then require the PRIMARY deployment to be COMPLETED on the new revision
#      (ECS's own circuit breaker may already have rolled back; "stable" alone is not proof of success)
#   4. on any failure: put every service back on its previous task definition and exit non-zero
# Usage: ecs-deploy.sh <env> <image>   (needs AWS_REGION and credentials in the environment)
set -euo pipefail

ENVIRONMENT="${1:?environment required}"
IMAGE="${2:?image required}"
PREFIX="mc-${ENVIRONMENT}"
CLUSTER="$PREFIX"
HERE="$(cd "$(dirname "$0")" && pwd)"
SERVICES=(api ws worker beat)

declare -A PREVIOUS NEW

for s in "${SERVICES[@]}"; do
  PREVIOUS[$s]="$(aws ecs describe-services --cluster "$CLUSTER" --services "${PREFIX}-${s}" \
    --query 'services[0].taskDefinition' --output text)"
  echo "previous ${s}: ${PREVIOUS[$s]}"
done

rollback() {
  echo "::error::Deploy failed, rolling back to previous task definitions" >&2
  for s in "${SERVICES[@]}"; do
    aws ecs update-service --cluster "$CLUSTER" --service "${PREFIX}-${s}" \
      --task-definition "${PREVIOUS[$s]}" >/dev/null || echo "rollback of ${s} could not be requested" >&2
  done
  aws ecs wait services-stable --cluster "$CLUSTER" \
    --services "${SERVICES[@]/#/${PREFIX}-}" || echo "services did not stabilise after rollback" >&2
}

deploy() {
  for s in "${SERVICES[@]}"; do
    # Explicit `|| return 1`: this function runs inside `if`, where `set -e` is not honoured.
    NEW[$s]="$("$HERE/ecs-register-revision.sh" "${PREFIX}-${s}" "$IMAGE")" || return 1
    echo "new ${s}: ${NEW[$s]}"
    aws ecs update-service --cluster "$CLUSTER" --service "${PREFIX}-${s}" \
      --task-definition "${NEW[$s]}" >/dev/null || return 1
  done

  aws ecs wait services-stable --cluster "$CLUSTER" --services "${SERVICES[@]/#/${PREFIX}-}" || return 1

  for s in "${SERVICES[@]}"; do
    STATE="$(aws ecs describe-services --cluster "$CLUSTER" --services "${PREFIX}-${s}" --output json \
      | jq -r '.services[0] | [.taskDefinition, (.deployments[] | select(.status=="PRIMARY") | .rolloutState)] | @tsv')" \
      || return 1
    CURRENT_TD="$(cut -f1 <<<"$STATE")"
    ROLLOUT="$(cut -f2 <<<"$STATE")"
    if [ "$CURRENT_TD" != "${NEW[$s]}" ] || [ "$ROLLOUT" != "COMPLETED" ]; then
      echo "Service ${s} is on ${CURRENT_TD} with rolloutState=${ROLLOUT}; expected ${NEW[$s]} COMPLETED" >&2
      return 1
    fi
  done
}

if deploy; then
  echo "Deploy of ${IMAGE} to ${ENVIRONMENT} completed."
else
  rollback
  exit 1
fi

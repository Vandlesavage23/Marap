#!/usr/bin/env bash
# Register a new revision of an ECS task definition family with a new image and print the new ARN.
# The latest revision of the family is cloned, so configuration changes applied by Terraform are kept;
# only containerDefinitions[0].image changes. Secrets stay as `secrets` references (valueFrom ARNs).
# Usage: ecs-register-revision.sh <family> <image>
set -euo pipefail

FAMILY="${1:?family required}"
IMAGE="${2:?image required}"

aws ecs describe-task-definition --task-definition "$FAMILY" --query taskDefinition --output json \
  | jq --arg image "$IMAGE" '
      del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .compatibilities,
          .registeredAt, .registeredBy, .deregisteredAt)
      | .containerDefinitions[0].image = $image' > "${RUNNER_TEMP:-/tmp}/taskdef-${FAMILY}.json"

aws ecs register-task-definition --cli-input-json "file://${RUNNER_TEMP:-/tmp}/taskdef-${FAMILY}.json" \
  --query taskDefinition.taskDefinitionArn --output text

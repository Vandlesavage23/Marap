#!/usr/bin/env bash
# main.tf, versions.tf, github_actions.tf and outputs.tf are intentionally identical in every environment
# (environments differ only in variables.tf defaults, backend.tf and tfvars). Fails if they drift.
set -euo pipefail
cd "$(dirname "$0")/../terraform/envs"
rc=0
for f in main.tf versions.tf github_actions.tf outputs.tf; do
  for e in staging prod; do
    if ! diff -q "dev/$f" "$e/$f" >/dev/null; then echo "DRIFT: $e/$f differs from dev/$f"; rc=1; fi
  done
done
exit $rc

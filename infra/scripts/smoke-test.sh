#!/usr/bin/env bash
# Smoke test: GET https://api.<domain>/ready must return 200 (database and Redis reachable, per the app's
# readiness probe). Retries to ride out target registration.
# Usage: smoke-test.sh <domain> [attempts]
set -euo pipefail

DOMAIN="${1:?domain required}"
ATTEMPTS="${2:-30}"
URL="https://api.${DOMAIN}/ready"

for i in $(seq 1 "$ATTEMPTS"); do
  CODE="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 "$URL" || echo 000)"
  echo "attempt ${i}/${ATTEMPTS}: ${URL} -> ${CODE}"
  if [ "$CODE" = "200" ]; then
    exit 0
  fi
  sleep 10
done
echo "Smoke test failed: ${URL} never returned 200" >&2
exit 1

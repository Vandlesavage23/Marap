#!/usr/bin/env bash
# Runs the Dart contract tests (test/contract) against a REAL Django server:
#   migrate -> (moto S3) -> deterministic fixture -> start server -> flutter test --tags contract -> stop.
#
# Needs Postgres 16 + Redis reachable via DATABASE_URL / TEST_REDIS_URL (defaults below), `uv`, `flutter`.
# Arguments replace the default target (test/contract), e.g.
#   tool/run_contract_tests.sh test/contract/social_contract_test.dart
#
# Isolation: use a throw-away database and a dedicated Redis db number; the fixture is wiped and
# rebuilt on every run (`contract_fixture --reset`). Never point this at a shared database. The server
# uses devtools.contract_settings (= config.settings.test: fake SMS/Play/gateway providers, in-memory
# channel layer, eager Celery, host api.mc.test) so no vendor is ever called.
#
# S3 (media upload tests): a `moto_server` is started from the backend env. moto's server mode needs
# Flask, which is not in backend/pyproject.toml; the script pip-installs it into a temp dir (needs
# network). If that fails the media tests are skipped (MC_CONTRACT_S3=0) and everything else runs.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE="$(cd "$HERE/.." && pwd)"
BACKEND="$(cd "$MOBILE/../../backend" && pwd)"
PORT="${MC_CONTRACT_PORT:-8765}"
S3_PORT="${MC_CONTRACT_S3_PORT:-5557}"
WORK="${MC_CONTRACT_WORK:-$(mktemp -d)}"
FIXTURE="$WORK/fixture.json"
LOG="$WORK/server.log"

export DATABASE_URL="${DATABASE_URL:-postgres://mc:mc@localhost:5432/mc_contract}"
# config.settings.test reads TEST_REDIS_URL (not REDIS_URL). Do not share db 15 with pytest: it flushes it.
export TEST_REDIS_URL="${TEST_REDIS_URL:-redis://localhost:6379/3}"
export REDIS_URL="$TEST_REDIS_URL"
# Tokens must outlive a slow first compile of the Dart tests (default lifetime is 15 minutes).
export ACCESS_TOKEN_MINUTES="${ACCESS_TOKEN_MINUTES:-180}"
# Store-review account: a fixed OTP, so the onboarding test can sign in for real (ApiAuthRepository.verifyOtp).
export REVIEW_ACCOUNT_PHONE="${REVIEW_ACCOUNT_PHONE:-+256770999001}"
export REVIEW_ACCOUNT_CODE="${REVIEW_ACCOUNT_CODE:-424242}"
export DJANGO_SETTINGS_MODULE=devtools.contract_settings
export PATH="${FLUTTER_BIN:-/opt/flutter/bin}:$PATH"

PIDS=()
cleanup() {
  for pid in "${PIDS[@]:-}"; do
    if [ -n "$pid" ]; then kill "$pid" 2>/dev/null || true; fi
  done
  wait 2>/dev/null || true
}
trap cleanup EXIT

cd "$BACKEND"
VENV_BIN="$(uv run python -c 'import sys; print(sys.prefix)' 2>/dev/null | tail -1)/bin"

echo "== migrate ($DATABASE_URL)"
uv run python manage.py migrate --noinput >"$WORK/migrate.log" 2>&1 || { tail -30 "$WORK/migrate.log"; exit 1; }
uv run python -c "
import django; django.setup()
from mc.common.redis import get_redis; get_redis().flushdb()" >/dev/null 2>&1

S3_OK=0
if [ -x "$VENV_BIN/moto_server" ]; then
  DEPS="$WORK/pydeps"
  if ! "$VENV_BIN/python" -c 'import flask' 2>/dev/null; then
    python3 -m pip install -q --target "$DEPS" flask flask-cors >"$WORK/pip.log" 2>&1 || true
  fi
  PYTHONPATH="$DEPS" "$VENV_BIN/moto_server" -p "$S3_PORT" >"$WORK/moto.log" 2>&1 &
  PIDS+=($!)
  for _ in $(seq 1 30); do
    if curl -fsS "http://127.0.0.1:$S3_PORT/" >/dev/null 2>&1; then S3_OK=1; break; fi
    sleep 0.5
  done
  if [ "$S3_OK" = 1 ]; then
    export MC_CONTRACT_S3_ENDPOINT="http://127.0.0.1:$S3_PORT"
    "$VENV_BIN/python" - <<'PY'
import django
django.setup()
import boto3
from django.conf import settings
c = boto3.client("s3", region_name=settings.AWS_REGION, aws_access_key_id="x", aws_secret_access_key="x",
                 endpoint_url=settings.AWS_S3_ENDPOINT_URL)
for b in (settings.MEDIA_BUCKET, settings.EXPORTS_BUCKET):
    c.create_bucket(Bucket=b, CreateBucketConfiguration={"LocationConstraint": settings.AWS_REGION})
PY
  else
    echo "!! moto_server did not start (see $WORK/moto.log): media tests will be skipped"
  fi
fi

echo "== fixture"
uv run python manage.py contract_fixture --reset --out "$FIXTURE" >"$WORK/fixture.log" 2>&1 \
  || { tail -30 "$WORK/fixture.log"; exit 1; }

echo "== server on :$PORT (log: $LOG)"
"$VENV_BIN/uvicorn" config.asgi:application --port "$PORT" --log-level warning >"$LOG" 2>&1 &
SERVER=$!
PIDS+=("$SERVER")
for _ in $(seq 1 60); do
  if curl -fsS -H 'Host: api.mc.test' "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then break; fi
  kill -0 "$SERVER" 2>/dev/null || { echo "server died:"; tail -30 "$LOG"; exit 1; }
  sleep 0.5
done

echo "== flutter test --tags contract"
cd "$MOBILE"
# Only compile/run the contract directory (a bare `flutter test --tags contract` still loads every test file).
TARGETS=("$@")
if [ ${#TARGETS[@]} -eq 0 ]; then TARGETS=(test/contract); fi
MC_CONTRACT_API="http://127.0.0.1:$PORT" MC_CONTRACT_FIXTURE="$FIXTURE" \
  MC_CONTRACT_S3="$S3_OK" \
  flutter test --tags contract --concurrency=1 "${TARGETS[@]}"

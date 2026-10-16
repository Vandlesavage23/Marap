#!/usr/bin/env bash
# Local load run on one machine (NOT staging sizing): migrate a scratch DB, build a bulk fixture, start the ASGI server
# with N workers, run k6 (HTTP mix + WebSockets), print summaries. Needs Postgres, Redis, uv, k6 (K6=/path/to/k6).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; BACKEND="$HERE/../backend"; WORK="${WORK:-$(mktemp -d)}"
K6="${K6:-k6}"; PORT="${PORT:-8100}"; WSPORT="${WSPORT:-8101}"; WORKERS="${WORKERS:-3}"; USERS="${USERS:-2000}"; PAIRS="${PAIRS:-400}"
VUS="${VUS:-150}"; DURATION="${DURATION:-3m}"; SOCKETS="${SOCKETS:-300}"
export DATABASE_URL="${DATABASE_URL:-postgres://mc:mc@localhost:5432/mc_load}" REDIS_URL="${REDIS_URL:-redis://localhost:6379/5}"
export DJANGO_SETTINGS_MODULE=config.settings.local MC_DOMAIN=mc.test ACCESS_TOKEN_MINUTES=240
export OTP_SENDS_PER_IP_PER_HOUR=100000 PYTHONUNBUFFERED=1
cd "$BACKEND"
PGPASSWORD=mc psql -h localhost -U mc -d postgres -qc "drop database if exists mc_load" -c "create database mc_load"
redis-cli -n 5 flushdb >/dev/null
uv run python manage.py migrate -v0
uv run python manage.py load_fixture --users "$USERS" --pairs "$PAIRS" --out "$WORK/tokens.json"
uv run gunicorn config.wsgi:application --worker-class gthread --workers "$WORKERS" --threads 8 -b "127.0.0.1:$PORT" --log-level warning >"$WORK/server.log" 2>&1 &
SERVER=$!
uv run uvicorn config.asgi:application --port "$WSPORT" --workers 1 --log-level warning >"$WORK/ws.log" 2>&1 &
WSSERVER=$!; trap 'kill $SERVER $WSSERVER 2>/dev/null || true' EXIT
for _ in $(seq 1 60); do curl -sf "http://127.0.0.1:$PORT/ready" >/dev/null && curl -sf "http://127.0.0.1:$WSPORT/ready" >/dev/null && break; sleep 1; done
echo "== HTTP mix: $VUS VUs for $DURATION"
"$K6" run -q -e BASE="http://127.0.0.1:$PORT" -e HOST=api.mc.test -e TOKENS_FILE="$WORK/tokens.json" -e VUS="$VUS" -e DURATION="$DURATION" "$HERE/api_mix.js" || echo "HTTP THRESHOLDS FAILED"
echo "== WebSockets: $SOCKETS sockets"
python3 - "$WORK/tokens.json" "$WORK/ws_tokens.json" <<'PY'
import json,sys
t=sorted([x for x in json.load(open(sys.argv[1])) if x["match_id"]], key=lambda x: x["match_id"])  # partners adjacent so both ends of a chat are connected
json.dump(t,open(sys.argv[2],"w"))
PY
RAMP=${RAMP:-30s} HOLD=${HOLD:-100s} SEND_EVERY_MS=${SEND_EVERY_MS:-20000} SOCKET_LIFETIME_MS=${SOCKET_LIFETIME_MS:-150000} "$K6" run -q -e BASE="ws://127.0.0.1:$WSPORT" -e HOST_HEADER=api.mc.test -e TOKENS_FILE="$WORK/ws_tokens.json" -e SOCKETS="$SOCKETS" "$HERE/ws_chat.js" || echo "WS THRESHOLDS FAILED"
echo "server log tail:"; tail -5 "$WORK/server.log"; echo "work dir: $WORK"

#!/usr/bin/env bash
# Builds (when asked, or when there is no build yet) and serves the Demo-mode
# web build, so the whole app can be tried in a browser with no backend.
#
#   tool/serve_demo_web.sh                    # serve build/web on :8080
#   tool/serve_demo_web.sh --build            # (re)build first, then serve
#   PORT=9000 tool/serve_demo_web.sh
#   tool/serve_demo_web.sh --build --dart-define=DEMO_SCENARIO=member
#
# Needs the Flutter SDK on PATH (or FLUTTER=/path/to/flutter) and python3.
# The first browser load fetches Roboto from Google Fonts when online.
set -euo pipefail
cd "$(dirname "$0")/.."

PORT="${PORT:-8080}"
FLUTTER="${FLUTTER:-flutter}"

[[ -f web/sqlite3.wasm ]] || tool/prepare_demo_web.sh

if [[ "${1:-}" == "--build" || ! -f build/web/main.dart.js ]]; then
  [[ "${1:-}" == "--build" ]] && shift
  # --no-web-resources-cdn: the page works without internet (except Roboto).
  "$FLUTTER" build web -t lib/main_demo.dart --no-web-resources-cdn "$@"
fi

echo "Demo mode (no backend): http://localhost:${PORT}/  (Ctrl+C to stop)"
exec python3 -m http.server "$PORT" --directory build/web

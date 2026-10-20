#!/usr/bin/env bash
# Copies sqlite3.wasm (it ships inside the drift package) to web/, where the
# Demo-mode web build looks for it. Run once after `flutter pub get`; both
# `flutter run -d chrome -t lib/main_demo.dart` and tool/serve_demo_web.sh need it.
# web/sqlite3.wasm is git-ignored (a 750 KB binary that already lives in the pub cache).
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -f .dart_tool/package_config.json ]] || { echo "run 'flutter pub get' first" >&2; exit 1; }
WASM="$(python3 - <<'PY'
import json, os
cfg = json.load(open('.dart_tool/package_config.json'))
for p in cfg['packages']:
    if p['name'] == 'drift':
        root = p['rootUri']
        root = root[len('file://'):] if root.startswith('file://') else os.path.normpath(os.path.join('.dart_tool', root))
        print(os.path.join(root, 'extension/devtools/build/sqlite3.wasm'))
PY
)"
[[ -f "$WASM" ]] || { echo "sqlite3.wasm not found at $WASM" >&2; exit 1; }
cp "$WASM" web/sqlite3.wasm
echo "copied $WASM -> web/sqlite3.wasm"

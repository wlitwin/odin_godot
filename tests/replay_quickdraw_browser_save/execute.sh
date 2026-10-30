#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
web="$1";work="$2";mkdir -p "$work";port=$((21000+RANDOM%8000));pid=""
trap '[[ -z "$pid" ]] || { kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true; };echo "Quickdraw browser save logs: $work"' EXIT
bash "$ROOT/tests/web/serve.sh" "$web/project/out" "$port" >"$work/http.log" 2>&1 &pid=$!
node "$ROOT/tests/replay_quickdraw_browser_save/browser.mjs" "http://127.0.0.1:$port/index.html" "$work/browser" >"$work/driver.log" 2>&1
cat "$work/driver.log"

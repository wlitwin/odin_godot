#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/tests/replay_rotation_godot"
work="${REPLAY_ROTATION_GODOT_OUT:-$(mktemp -d)}"
mkdir -p "$work" "$PROJ/out"; touch "$PROJ/out/.gdignore"
echo "Rotation browser logs: $work"
bash "$ROOT/build/build_web.sh" "$PROJ" >"$work/web-build.log" 2>&1
REPLAY_ROTATION_GODOT_OUT="$work/native" bash "$PROJ/run.sh" >"$work/native.log" 2>&1
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
"$GODOT" --headless --path "$PROJ" --export-release Web "$PROJ/out/index.html" >"$work/export.log" 2>&1
[[ -f "$PROJ/out/libodin_godot.wasm" && -f "$PROJ/out/index.side.wasm" ]]
[[ -d "$ROOT/tests/web/node_modules/puppeteer-core" ]]
if [[ ! -e "$PROJ/node_modules" ]]; then ln -s "$ROOT/tests/web/node_modules" "$PROJ/node_modules"; fi
PORT="${PORT:-$((20000+RANDOM%10000))}"
bash "$ROOT/tests/web/serve.sh" "$PROJ/out" "$PORT" >"$work/http.log" 2>&1 & http_pid=$!
trap 'kill "$http_pid" 2>/dev/null || true' EXIT
for _ in {1..60}; do if curl -fsS -o /dev/null "http://127.0.0.1:$PORT/index.html" 2>/dev/null; then break; fi; sleep 0.1; done
ROTATION_BROWSER_LOG="$work/browser.log" node "$PROJ/drive.mjs" "http://127.0.0.1:$PORT/index.html"

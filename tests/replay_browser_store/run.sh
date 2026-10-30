#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/tests/replay_browser_store";work="${BROWSER_STORE_LOGS:-$(mktemp -d)}";mkdir -p "$work" "$PROJ/out";touch "$PROJ/out/.gdignore"
echo "Browser storage logs: $work"
node "$PROJ/availability.mjs" >"$work/availability.log"
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]];then
 bash "$ROOT/build/build_web.sh" "$PROJ" >"$work/web-build.log" 2>&1
 bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/native-build.log" 2>&1
fi
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
"$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log";then cat "$work/import.log";exit 1;fi
"$GODOT" --headless --path "$PROJ" --quit-after 600 >"$work/native.log" 2>&1
rg -q REPLAY_BROWSER_STORE_NATIVE_OK "$work/native.log"
if rg -q 'SCRIPT ERROR|ERROR:|instances were leaked' "$work/import.log" "$work/native.log";then cat "$work/import.log" "$work/native.log";exit 1;fi
"$GODOT" --headless --path "$PROJ" --export-release Web "$PROJ/out/index.html" >"$work/export.log" 2>&1
[[ -f "$PROJ/out/libodin_godot.wasm" ]]
if [[ ! -e "$PROJ/node_modules" ]];then ln -s "$ROOT/tests/web/node_modules" "$PROJ/node_modules";fi
PORT="${PORT:-$((20000+RANDOM%10000))}"
bash "$ROOT/tests/web/serve.sh" "$PROJ/out" "$PORT" >"$work/http.log" 2>&1 & http_pid=$!
trap 'kill "$http_pid" 2>/dev/null || true' EXIT
BROWSER_STORE_LOGS="$work" node "$PROJ/drive.mjs" "http://127.0.0.1:$PORT/index.html"

#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"; export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_scrapyard"; SERVER="$ROOT/tests/replay_web_authority/server"; work="${RSB_UI_LOGS:-$(mktemp -d)}"
mkdir -p "$work" "$PROJ/out"; touch "$PROJ/out/.gdignore"
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]]; then
  for project in "$SERVER" "$PROJ"; do
    label="${project##*/}"
    bash "$ROOT/build/build_scripts.sh" "$project" >"$work/build-$label.log" 2>&1
    ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext" "$GODOT" --headless --path "$project" --editor --quit-after 120 >"$work/import-$label.log" 2>&1
    if rg -q 'SCRIPT ERROR|ERROR:' "$work/import-$label.log"; then cat "$work/import-$label.log"; exit 1; fi
    python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$project" "$work/build-wait-$label.json"
    bash "$ROOT/build/build_scripts.sh" "$project" >"$work/final-build-$label.log" 2>&1
  done
  bash "$ROOT/build/build_web.sh" "$PROJ" >"$work/web-build.log" 2>&1
fi
ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext" "$GODOT" --headless --path "$PROJ" --export-release Web "$PROJ/out/index.html" >"$work/export.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/export.log"; then cat "$work/export.log"; exit 1; fi
[[ -f "$PROJ/out/libodin_godot.wasm" ]]
if [[ ! -e "$PROJ/node_modules" ]]; then ln -s "$ROOT/tests/web/node_modules" "$PROJ/node_modules"; fi
PORT="${PORT:-$((21000 + RANDOM % 9000))}"; CONTROL="${CONTROL:-$((31000 + RANDOM % 9000))}"
http_pid=""; server_pid=""
cleanup() { kill ${http_pid:-} ${server_pid:-} 2>/dev/null || true; [[ -z "$http_pid" ]] || wait "$http_pid" 2>/dev/null || true; [[ -z "$server_pid" ]] || wait "$server_pid" 2>/dev/null || true; echo "Browser UI logs: $work"; }
trap cleanup EXIT
bash "$ROOT/tests/web/serve.sh" "$PROJ/out" "$PORT" >"$work/http.log" 2>&1 & http_pid=$!
RWA_SIGNAL=1 RWA_SIGNAL_ONLY=1 RWA_GAME=scrapyard RWA_PORT="$CONTROL" RWA_DB="$work/authority.sqlite" RWA_DONE="$work/done" ODIN_SCRIPTS_DLL="$SERVER/bin/libodinscripts.$ext" "$GODOT" --headless --path "$SERVER" >"$work/server.log" 2>&1 & server_pid=$!
for _ in {1..100}; do if rg -q WEB_AUTHORITY_SERVER_READY "$work/server.log"; then break; fi; sleep 0.1; done
rg -q WEB_AUTHORITY_SERVER_READY "$work/server.log"
node "$PROJ/web_ui_drive.mjs" "http://127.0.0.1:$PORT/index.html" "ws://127.0.0.1:$CONTROL/control" "$work/browser" | tee "$work/driver.log"
touch "$work/done"; wait "$server_pid"; server_pid=""
if rg -q 'WEB_AUTHORITY_FAIL|SCRIPT ERROR|ERROR:|instances were leaked' "$work/server.log"; then cat "$work/server.log"; exit 1; fi

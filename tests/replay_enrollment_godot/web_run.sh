#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"; export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/tests/replay_enrollment_godot"; SERVER="$ROOT/tests/replay_provision_godot"
work="${REPLAY_ENROLLMENT_WEB_OUT:-$(mktemp -d)}"; mkdir -p "$work" "$PROJ/out"; touch "$PROJ/out/.gdignore"
server=""; http=""
cleanup() { for pid in "$server" "$http"; do if [[ -n "$pid" ]]; then kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; fi; done; echo "Browser enrollment logs: $work"; }
trap cleanup EXIT
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
for proj in "$SERVER" "$PROJ"; do
    label="$(basename "$proj")"; export ODIN_SCRIPTS_DLL="$proj/bin/libodinscripts.$ext"
    bash "$ROOT/build/build_scripts.sh" "$proj" >"$work/$label-build.log" 2>&1
    "$GODOT" --headless --path "$proj" --editor --quit-after 90 >"$work/$label-import.log" 2>&1
    if rg -q 'SCRIPT ERROR|ERROR:' "$work/$label-import.log"; then cat "$work/$label-import.log"; exit 1; fi
    python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$proj" "$work/$label-wait.json"
    bash "$ROOT/build/build_scripts.sh" "$proj" >"$work/$label-final-build.log" 2>&1
done
# The simple import preflight scans native.odin despite its darwin/linux build
# tags. Odin excludes it on WASM and compiles browser.odin's explicit stubs.
ODIN_WEB_PREFLIGHT=0 bash "$ROOT/build/build_web.sh" "$PROJ" >"$work/web-build.log" 2>&1
ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext" "$GODOT" --headless --path "$PROJ" --export-release Web "$PROJ/out/index.html" >"$work/export.log" 2>&1
[[ -f "$PROJ/out/libodin_godot.wasm" ]]
if [[ ! -e "$PROJ/node_modules" ]]; then ln -s "$ROOT/tests/web/node_modules" "$PROJ/node_modules"; fi
port=$((21000+RANDOM%9000)); control=$((31000+RANDOM%9000))
PROVISION_ROLE=server PROVISION_ENROLLMENT=1 PROVISION_PLAIN=1 PROVISION_PORT="$control" PROVISION_DB="$work/server.sqlite3" PROVISION_DONE="$work/done" ODIN_SCRIPTS_DLL="$SERVER/bin/libodinscripts.$ext" "$GODOT" --headless --max-fps 120 --path "$SERVER" >"$work/server.log" 2>&1 & server=$!
bash "$ROOT/tests/web/serve.sh" "$PROJ/out" "$port" >"$work/http.log" 2>&1 & http=$!
for _ in {1..100}; do if curl -fsS -o /dev/null "http://127.0.0.1:$port/index.html" 2>/dev/null && rg -q PROVISION_TLS_SERVER_READY "$work/server.log"; then break; fi; sleep 0.1; done
ENROLLMENT_BROWSER_LOGS="$work/browser" node "$PROJ/drive.mjs" "http://127.0.0.1:$port/index.html" "ws://127.0.0.1:$control/admission" | tee "$work/driver.log"
touch "$work/done"; wait "$server"; server=""
rg -q 'ENROLLMENT_SERVER_OK rooms=2 members=2' "$work/server.log"
if rg -q 'PROVISION_TLS_FAIL|SCRIPT ERROR|ERROR:|instances were leaked|resources still in use' "$work/server.log"; then exit 1; fi
echo REPLAY_ENROLLMENT_WEB_OK

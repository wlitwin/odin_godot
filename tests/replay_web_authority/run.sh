#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/tests/replay_web_authority";work="${RWA_LOGS:-$(mktemp -d)}"
mkdir -p "$work" "$PROJ/client/out";touch "$PROJ/client/out/.gdignore"
echo "Browser authority logs: $work"
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]]; then
 bash "$ROOT/build/build_scripts.sh" "$PROJ/server" >"$work/server-build.log" 2>&1
 bash "$ROOT/build/build_web.sh" "$PROJ/client" >"$work/web-build.log" 2>&1
 bash "$ROOT/build/build_scripts.sh" "$PROJ/client" >"$work/client-build.log" 2>&1
fi
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
for part in server client;do
 ODIN_SCRIPTS_DLL="$PROJ/$part/bin/libodinscripts.$ext" "$GODOT" --headless --path "$PROJ/$part" --editor --quit-after 120 >"$work/$part-import.log" 2>&1
 if rg -q 'SCRIPT ERROR|ERROR:' "$work/$part-import.log";then cat "$work/$part-import.log";exit 1;fi
 python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$PROJ/$part" "$work/$part-wait.json"
 if [[ "${REPLAY_PREBUILT:-0}" != 1 ]];then bash "$ROOT/build/build_scripts.sh" "$PROJ/$part" >"$work/$part-final-build.log" 2>&1;fi
done
ODIN_SCRIPTS_DLL="$PROJ/client/bin/libodinscripts.$ext" "$GODOT" --headless --path "$PROJ/client" --export-release Web "$PROJ/client/out/index.html" >"$work/export.log" 2>&1
[[ -f "$PROJ/client/out/libodin_godot.wasm" ]]
[[ -d "$ROOT/tests/web/node_modules/puppeteer-core" ]]
if [[ ! -e "$PROJ/node_modules" ]];then ln -s "$ROOT/tests/web/node_modules" "$PROJ/node_modules";fi
PORT="${PORT:-$((21000+RANDOM%9000))}";CONTROL="${CONTROL:-$((31000+RANDOM%9000))}"
RWA_PORT="$CONTROL" RWA_DB="$work/authority.sqlite" RWA_DONE="$work/done" ODIN_SCRIPTS_DLL="$PROJ/server/bin/libodinscripts.$ext" "$GODOT" --headless --path "$PROJ/server" >"$work/server.log" 2>&1 & server_pid=$!
bash "$ROOT/tests/web/serve.sh" "$PROJ/client/out" "$PORT" >"$work/http.log" 2>&1 & http_pid=$!
trap 'kill "$server_pid" "$http_pid" 2>/dev/null || true' EXIT
for _ in {1..100};do
 if curl -fsS -o /dev/null "http://127.0.0.1:$PORT/index.html" 2>/dev/null && rg -q WEB_AUTHORITY_SERVER_READY "$work/server.log";then break;fi
 sleep 0.1
done
if [[ "${RWA_SIGNAL:-0}" == 1 ]];then
 RWA_SIGNAL_LOGS="$work/signal" node "$PROJ/signal_drive.mjs" "http://127.0.0.1:$PORT/index.html" "ws://127.0.0.1:$CONTROL/control" | tee "$work/driver.log"
else
 RWA_BROWSER_LOG="$work/browser.log" node "$PROJ/drive.mjs" "http://127.0.0.1:$PORT/index.html" "ws://127.0.0.1:$CONTROL/control" | tee "$work/driver.log"
fi
touch "$work/done"
wait "$server_pid"
cat "$work/server.log"
if rg -q 'WEB_AUTHORITY_FAIL|SCRIPT ERROR|ERROR:|instances were leaked|resources still in use' "$work/server.log";then exit 1;fi
rg -q WEB_AUTHORITY_SERVER_OK "$work/server.log"
if [[ "${RWA_SIGNAL:-0}" == 1 ]];then rg -q RZA_SERVER_OK "$work/server.log";echo REPLAY_AUTHENTICATED_RTC_SERVICE_OK;else echo REPLAY_WEB_AUTHORITY_OK;fi

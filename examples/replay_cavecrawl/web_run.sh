#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_cavecrawl";SERVER="$ROOT/tests/replay_web_authority/server";work="${RCB_LOGS:-$(mktemp -d)}"
mkdir -p "$work" "$PROJ/out";touch "$PROJ/out/.gdignore";echo "Browser migration logs: $work"
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]];then
 bash "$ROOT/build/build_scripts.sh" "$SERVER" >"$work/server-build.log" 2>&1
 bash "$ROOT/build/build_web.sh" "$PROJ" >"$work/web-build.log" 2>&1
 bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/native-build.log" 2>&1
fi
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
for project in "$PROJ" "$SERVER";do
 ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext" "$GODOT" --headless --path "$project" --editor --quit-after 120 >"$work/import.log" 2>&1
 if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log";then cat "$work/import.log";exit 1;fi
done
ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext" "$GODOT" --headless --path "$PROJ" --export-release Web "$PROJ/out/index.html" >"$work/export.log" 2>&1
[[ -f "$PROJ/out/libodin_godot.wasm" ]]
if [[ ! -e "$PROJ/node_modules" ]];then ln -s "$ROOT/tests/web/node_modules" "$PROJ/node_modules";fi
PORT="${PORT:-$((21000+RANDOM%9000))}";CONTROL="${CONTROL:-$((31000+RANDOM%9000))}"
bash "$ROOT/tests/web/serve.sh" "$PROJ/out" "$PORT" >"$work/http.log" 2>&1 & http_pid=$!
server_pid="";trap 'kill "$http_pid" ${server_pid:-} 2>/dev/null || true' EXIT
for mode in ${RCB_MODES:-planned crash repeat partition successor_loss return signaling};do
 mkdir -p "$work/$mode"
 signal_only=0;if [[ "$mode" == signaling ]];then signal_only=1;fi
 RWA_SIGNAL_ONLY="$signal_only" RWA_SIGNAL=1 RWA_GAME=cave RWA_PORT="$CONTROL" RWA_DB="$work/$mode/authority.sqlite" RWA_DONE="$work/$mode/done" ODIN_SCRIPTS_DLL="$SERVER/bin/libodinscripts.$ext" "$GODOT" --headless --path "$SERVER" >"$work/$mode/server.log" 2>&1 & server_pid=$!
 for _ in {1..100};do if rg -q WEB_AUTHORITY_SERVER_READY "$work/$mode/server.log";then break;fi;sleep 0.1;done
 RCB_LOGS="$work/$mode" node "$PROJ/web_drive.mjs" "http://127.0.0.1:$PORT/index.html" "ws://127.0.0.1:$CONTROL/control" "$mode" | tee "$work/$mode/driver.log"
 touch "$work/$mode/done";wait "$server_pid";server_pid=""
 if rg -q 'WEB_AUTHORITY_FAIL|SCRIPT ERROR|ERROR:|instances were leaked' "$work/$mode/server.log";then cat "$work/$mode/server.log";exit 1;fi
done
python3 "$PROJ/web_report.py" "$work"
echo REPLAY_CAVE_WEB_MIGRATION_OK

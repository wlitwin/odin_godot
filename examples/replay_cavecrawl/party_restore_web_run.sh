#!/usr/bin/env bash
set -euo pipefail
umask 077
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_cavecrawl";SERVICE="$ROOT/examples/replay_room_service"
work="${CAVE_PARTY_RESTORE_WEB_OUT:-$(mktemp -d)}";mkdir -p "$work" "$PROJ/out";touch "$PROJ/out/.gdignore"
server="";http_pid="";driver=""
cleanup(){ for pid in "$server" "$http_pid" "$driver";do if [[ -n "$pid" ]];then kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true;fi;done;echo "Browser party restore logs: $work"; };trap cleanup EXIT
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) exit 1 ;; esac
for project in "$SERVICE" "$PROJ";do
 name="$(basename "$project")";export ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext"
 bash "$ROOT/build/build_scripts.sh" "$project" >"$work/$name-build.log" 2>&1
 "$GODOT" --headless --path "$project" --editor --quit-after 90 >"$work/$name-import.log" 2>&1
 if rg -q 'SCRIPT ERROR|ERROR:' "$work/$name-import.log";then cat "$work/$name-import.log";exit 1;fi
 python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$project" "$work/$name-wait.json"
 bash "$ROOT/build/build_scripts.sh" "$project" >"$work/$name-final-build.log" 2>&1
done
bash "$ROOT/build/build_web.sh" "$PROJ" >"$work/web-build.log" 2>&1
ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext" "$GODOT" --headless --path "$PROJ" --export-release Web "$PROJ/out/index.html" >"$work/export.log" 2>&1
if [[ ! -e "$PROJ/node_modules" ]];then ln -s "$ROOT/tests/web/node_modules" "$PROJ/node_modules";fi
control=$((31000+RANDOM%9000));http=$((21000+RANDOM%9000))
start_service(){
 REPLAY_ROOM_CONTENT=0x4341564552504c39 REPLAY_ROOM_PORT="$control" REPLAY_ROOM_DB="$work/service.sqlite3" REPLAY_ROOM_CREATE_DB="$1" REPLAY_ROOM_LOCAL_DEVELOPMENT=1 ODIN_SCRIPTS_DLL="$SERVICE/bin/libodinscripts.$ext" "$GODOT" --headless --max-fps 120 --path "$SERVICE" >"$work/service-$1.log" 2>&1 &server=$!
 for _ in {1..150};do if rg -q REPLAY_ROOM_SERVICE_READY "$work/service-$1.log";then return;fi;if ! kill -0 "$server" 2>/dev/null;then return 1;fi;sleep 0.1;done;return 1
}
start_service 1
bash "$ROOT/tests/web/serve.sh" "$PROJ/out" "$http" >"$work/http.log" 2>&1 &http_pid=$!
for _ in {1..100};do if curl -fsS -o /dev/null "http://127.0.0.1:$http/index.html" 2>/dev/null;then break;fi;sleep 0.1;done
node "$PROJ/party_restore_web_drive.mjs" "http://127.0.0.1:$http/index.html" "ws://127.0.0.1:$control" "$work" >"$work/driver.log" 2>&1 &driver=$!
for _ in {1..600};do if [[ -f "$work/source-stopped" ]];then break;fi;if ! kill -0 "$driver" 2>/dev/null;then cat "$work/driver.log";exit 1;fi;sleep 0.1;done
[[ -f "$work/source-stopped" ]]
kill -KILL "$server";wait "$server" 2>/dev/null || true;server=""
start_service 0;touch "$work/service-restarted"
wait "$driver";driver=""
rg -q REPLAY_CAVE_PARTY_RESTORE_BROWSER_OK "$work/driver.log"
if rg -q 'SCRIPT ERROR|ERROR:|REPLAY_ROOM_SERVICE_FAIL' "$work"/service-*.log;then exit 1;fi
cat "$work/driver.log"
odin build "$ROOT/tests/replay_room_save_verify" -collection:godot="$ROOT" -out:"$work/verify-checkpoint"
"$work/verify-checkpoint" "$work/service.sqlite3" creator >"$work/durable-checkpoint.log"
cat "$work/durable-checkpoint.log"
echo REPLAY_CAVE_PARTY_RESTORE_WEB_OK

#!/usr/bin/env bash
set -euo pipefail
umask 077
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_scrapyard";SERVICE="$ROOT/examples/replay_room_service";work="${RSY_ONLINE_WEB_OUT:-$(mktemp -d)}";mkdir -p "$work/host" "$work/guest" "$PROJ/out";touch "$PROJ/out/.gdignore";pids=()
trap 'for pid in "${pids[@]}";do kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true;done;echo "Browser Scrapyard party logs: $work"' EXIT
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) exit 1 ;; esac
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]];then
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
fi
[[ -f "$PROJ/out/libodin_godot.wasm" ]]
odin build "$ROOT/tests/replay_scrapyard/online_seed" -collection:godot="$ROOT" -out:"$work/seed"
for role in host guest;do "$work/seed" "$work/$role" "$role";done
if [[ ! -e "$PROJ/node_modules" ]];then ln -s "$ROOT/tests/web/node_modules" "$PROJ/node_modules";fi
control=$((31000+RANDOM%9000));http=$((21000+RANDOM%9000))
REPLAY_ROOM_CONTENT=0x5253435241503048 REPLAY_ROOM_PORT="$control" REPLAY_ROOM_DB="$work/service.sqlite3" REPLAY_ROOM_CREATE_DB=1 REPLAY_ROOM_LOCAL_DEVELOPMENT=1 ODIN_SCRIPTS_DLL="$SERVICE/bin/libodinscripts.$ext" "$GODOT" --headless --max-fps 120 --path "$SERVICE" >"$work/service.log" 2>&1 &pids+=("$!")
bash "$ROOT/tests/web/serve.sh" "$PROJ/out" "$http" >"$work/http.log" 2>&1 &pids+=("$!")
for _ in {1..100};do if curl -fsS -o /dev/null "http://127.0.0.1:$http/index.html" 2>/dev/null && rg -q REPLAY_ROOM_SERVICE_READY "$work/service.log";then break;fi;sleep 0.1;done
node "$PROJ/online_web_drive.mjs" "http://127.0.0.1:$http/index.html" "ws://127.0.0.1:$control" "$work" "$PROJ/assets/gz2/bg_floor.png" | tee "$work/driver.log"
if rg -q 'SCRIPT ERROR|ERROR:|REPLAY_ROOM_SERVICE_FAIL' "$work/service.log";then exit 1;fi
echo REPLAY_SCRAPYARD_ONLINE_WEB_OK

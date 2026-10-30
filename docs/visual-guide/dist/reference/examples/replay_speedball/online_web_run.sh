#!/usr/bin/env bash
set -euo pipefail
umask 077
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_speedball";SERVICE="$ROOT/examples/replay_room_service";work="${RSB_WEB_OUT:-$(mktemp -d)}";mkdir -p "$work";pids=()
[[ -z "$(ls -A "$work")" ]] || { echo "Output must be empty: $work" >&2;exit 2; }
trap 'for pid in "${pids[@]}";do kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true;done;echo "Speedball browser logs: $work"' EXIT
case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) exit 2;;esac
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]];then
 for project in "$SERVICE" "$PROJ";do
  label="$(basename "$project")";export ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext"
  bash "$ROOT/build/build_scripts.sh" "$project" >"$work/$label-build.log" 2>&1
  "$GODOT" --headless --path "$project" --editor --quit-after 90 >"$work/$label-import.log" 2>&1
  python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$project" "$work/$label-wait.json"
  bash "$ROOT/build/build_scripts.sh" "$project" >"$work/$label-final-build.log" 2>&1
  if rg -q 'SCRIPT ERROR|ERROR:' "$work/$label-import.log";then cat "$work/$label-import.log";exit 1;fi
 done
 bash "$ROOT/build/build_web.sh" "$PROJ" >"$work/web-build.log" 2>&1
 mkdir -p "$PROJ/out";touch "$PROJ/out/.gdignore"
 ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext" "$GODOT" --headless --path "$PROJ" --export-release Web "$PROJ/out/index.html" >"$work/export.log" 2>&1
fi
[[ -f "$PROJ/out/libodin_godot.wasm" ]]
control=$((31000+RANDOM%9000));http=$((21000+RANDOM%9000))
REPLAY_ROOM_CONTENT=0x5253504545444234 REPLAY_ROOM_PORT="$control" REPLAY_ROOM_DB="$work/service.sqlite3" REPLAY_ROOM_CREATE_DB=1 REPLAY_ROOM_LOCAL_DEVELOPMENT=1 ODIN_SCRIPTS_DLL="$SERVICE/bin/libodinscripts.$ext" "$GODOT" --headless --max-fps 120 --path "$SERVICE" >"$work/service.log" 2>&1 &pids+=("$!")
bash "$ROOT/tests/web/serve.sh" "$PROJ/out" "$http" >"$work/http.log" 2>&1 &pids+=("$!")
for _ in {1..100};do if curl -fsS -o /dev/null "http://127.0.0.1:$http/index.html" 2>/dev/null && rg -q REPLAY_ROOM_SERVICE_READY "$work/service.log";then break;fi;sleep .1;done
rg -q REPLAY_ROOM_SERVICE_READY "$work/service.log"
node "$PROJ/online_web_drive.mjs" "http://127.0.0.1:$http/index.html" "ws://127.0.0.1:$control" "$work/browser" | tee "$work/driver.log"
if rg -q 'SCRIPT ERROR|ERROR:|REPLAY_ROOM_SERVICE_FAIL' "$work/service.log";then exit 1;fi
echo REPLAY_SPEEDBALL_ONLINE_WEB_OK

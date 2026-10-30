#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
web="$1";service="$2";work="$3";mkdir -p "$work"
[[ -z "$(ls -A "$work")" ]] || { echo 'Fresh output required' >&2;exit 1; }
case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) exit 1;;esac
pids=();trap 'for pid in "${pids[@]}";do kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true;done;echo "Quickdraw online logs: $work"' EXIT
control=$((31000+RANDOM%8000));http=$((21000+RANDOM%8000))
REPLAY_ROOM_CONTENT=0x52515549434b4432 REPLAY_ROOM_CHECKPOINT_MODEL=quickdraw REPLAY_ROOM_PORT="$control" REPLAY_ROOM_DB="$work/service.sqlite3" REPLAY_ROOM_CREATE_DB=1 REPLAY_ROOM_LOCAL_DEVELOPMENT=1 ODIN_SCRIPTS_DLL="$service/project/bin/libodinscripts.$ext" "$GODOT" --headless --max-fps 120 --path "$service/project" >"$work/service.log" 2>&1 &pids+=("$!")
bash "$ROOT/tests/web/serve.sh" "$web/project/out" "$http" >"$work/http.log" 2>&1 &pids+=("$!")
for _ in {1..150};do if rg -q REPLAY_ROOM_SERVICE_READY "$work/service.log";then break;fi;sleep .1;done
rg -q REPLAY_ROOM_SERVICE_READY "$work/service.log"
node "$ROOT/tests/replay_quickdraw_online/browser.mjs" "http://127.0.0.1:$http/index.html" "ws://127.0.0.1:$control" "$work/browser" >"$work/driver.log" 2>&1
cat "$work/driver.log"
if rg -q 'SCRIPT ERROR|ERROR:|REPLAY_ROOM_SERVICE_FAIL' "$work/service.log";then exit 1;fi

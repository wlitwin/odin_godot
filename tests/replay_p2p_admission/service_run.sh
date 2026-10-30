#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/tests/replay_p2p_admission/server";work="${RDP_ADMISSION_LOGS:-$(mktemp -d)}";mkdir -p "$work"
pid="";trap 'if [[ -n "$pid" ]];then kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true;fi;echo "P2P admission logs: $work"' EXIT
case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) ext=dll;;esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]];then
 bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/build.log" 2>&1
 "$GODOT" --headless --path "$PROJ" --editor --quit-after 90 >"$work/import.log" 2>&1
 python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$PROJ" "$work/wait.json"
 bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/final-build.log" 2>&1
 if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log";then cat "$work/import.log";exit 1;fi
fi
[[ -e "$ROOT/tests/replay_p2p_admission/node_modules" ]] || ln -s "$ROOT/tests/web/node_modules" "$ROOT/tests/replay_p2p_admission/node_modules"
port=$((31000+RANDOM%10000))
RDP_AUTH_PLAYERS=3 RDP_AUTH_PORT="$port" RDP_AUTH_DONE="$work/done" "$GODOT" --headless --path "$PROJ" >"$work/server.log" 2>&1 &pid=$!
for _ in {1..100};do rg -q REPLAY_SIGNAL_READY "$work/server.log" && break;sleep .1;done
rg -q REPLAY_SIGNAL_READY "$work/server.log"
node "$ROOT/tests/replay_p2p_admission/mesh.mjs" "ws://127.0.0.1:$port/rtc" "$work/server.log" "$work/mesh.json" | tee "$work/driver.log"
touch "$work/done";wait "$pid";pid=""
rg -q P2P_ADMISSION_SERVICE_OK "$work/server.log"
if rg -q 'P2P_ADMISSION_SERVICE_FAIL|SCRIPT ERROR|ERROR:|instances were leaked|resources still in use' "$work/server.log";then cat "$work/server.log";exit 1;fi
echo REPLAY_P2P_ADMISSION_SERVICE_OK

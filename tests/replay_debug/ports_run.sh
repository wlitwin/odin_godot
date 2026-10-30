#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_DEBUG_PORTS_OUT:-$(mktemp -d)}";mkdir -p "$work";pids=()
trap 'for pid in "${pids[@]}";do kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true;done;echo "Debug port logs: $work"' EXIT
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
for name in hello cavecrawl;do
 project="$ROOT/examples/replay_$name"
 if [[ "${REPLAY_PREBUILT:-0}" != 1 ]];then bash "$ROOT/build/build_scripts.sh" "$project" >"$work/$name-build.log" 2>&1;fi
 ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext" "$GODOT" --headless --path "$project" --editor --quit-after 120 >"$work/$name-import.log" 2>&1
 if rg -q 'SCRIPT ERROR|ERROR:' "$work/$name-import.log";then cat "$work/$name-import.log";exit 1;fi
 python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$project" "$work/$name-build-wait.json"
done
project="$ROOT/examples/replay_hello"
DEBUG_PORT=hello ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext" "$GODOT" --headless --max-fps 60 --path "$project" --script "$ROOT/tests/replay_debug/port.gd" >"$work/hello.log" 2>&1
project="$ROOT/examples/replay_cavecrawl";port=$((40000+RANDOM%10000))
for role in host client;do
 DEBUG_PORT_DIR="$work" DEBUG_PORT=cave REPLAY_CAVE_ROLE="$role" REPLAY_CAVE_TOKEN="debug-$role" REPLAY_CAVE_PORT="$port" REPLAY_CAVE_LATENCY=120 ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext" "$GODOT" --headless --max-fps 60 --path "$project" --script "$ROOT/tests/replay_debug/port.gd" >"$work/$role.log" 2>&1 &pids+=("$!")
 sleep 0.3
done
for pid in "${pids[@]}";do wait "$pid";done;pids=()
for role in hello host client;do
 cat "$work/$role.log";rg -q REPLAY_DEBUG_PORT_OK "$work/$role.log"
 if rg -q 'SCRIPT ERROR|ERROR:|REPLAY_DEBUG_PORT_FAIL|instances were leaked|resources still in use' "$work/$role.log";then exit 1;fi
done
echo REPLAY_DEBUG_PORTS_OK

#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/tests/replay_steam";work="${REPLAY_STEAM_OUT:-$(mktemp -d)}";mkdir -p "$work";pids=()
trap 'for pid in "${pids[@]}";do kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true;done;echo "Steam contract logs: $work"' EXIT
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/build.log" 2>&1
"$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log";then cat "$work/import.log";exit 1;fi
python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$PROJ" "$work/build-wait.json"
bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/final-build.log" 2>&1
for scenario in main session;do
export STEAM_TEST_PORT=$((40000+RANDOM%10000))
for role in host client;do STEAM_TEST_ROLE="$role" "$GODOT" --headless --max-fps 60 --path "$PROJ" "$scenario.tscn" >"$work/$scenario-$role.log" 2>&1 &pids+=("$!");sleep 0.3;done
for pid in "${pids[@]}";do wait "$pid";done;pids=()
for role in host client;do cat "$work/$scenario-$role.log";rg -q "REPLAY_STEAM_(CONTRACT|SESSION)_OK role=$role" "$work/$scenario-$role.log";done
done
"$GODOT" --headless --path "$PROJ" failures.tscn >"$work/failures.log" 2>&1
rg -q REPLAY_STEAM_FAILURES_OK "$work/failures.log"
if rg -q 'REPLAY_STEAM_FAILURE_FAIL|REPLAY_STEAM_SESSION_FAIL|REPLAY_STEAM_CONTRACT_FAIL|SCRIPT ERROR|ERROR:|instances were leaked|resources still in use' "$work"/*.log;then exit 1;fi
odin check "$PROJ/scripts" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point -custom-attribute:gd_method
echo REPLAY_STEAM_CONTRACT_ALL_OK

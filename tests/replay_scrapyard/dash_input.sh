#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
project="$ROOT/examples/replay_scrapyard";work="${REPLAY_DASH_INPUT_OUT:-$(mktemp -d)}";mkdir -p "$work"
trap 'echo "Dash input logs: $work"' EXIT
case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) ext=dll;;esac
export ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext"
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]];then
 bash "$ROOT/build/build_scripts.sh" "$project" >"$work/build.log" 2>&1
 "$GODOT" --headless --path "$project" --editor --quit-after 90 >"$work/import.log" 2>&1
 if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log";then cat "$work/import.log";exit 1;fi
 python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$project" "$work/wait.json"
 bash "$ROOT/build/build_scripts.sh" "$project" >"$work/final-build.log" 2>&1
fi
RSY_ROLE=solo RSY_TOKEN=dash-input RSY_PERSIST=0 RSY_AUDIO=0 RSY_RUN=0 RSY_MOBS=0 RSY_RESUME=0 RSY_LATENCY=0 RSY_MODS_DIR="$work/no-mods" \
 "$GODOT" --headless --max-fps 60 --path "$project" --script dash_input_test.gd --quit-after 1200 >"$work/runtime.log" 2>&1
cat "$work/runtime.log"
rg -q REPLAY_DASH_INPUT_OK "$work/runtime.log"
if rg -q 'RSY_WORKBENCH_FAIL|REPLAY_SCRAPYARD_FAIL|ERROR:|SCRIPT ERROR|instances were leaked|resources still in use' "$work/runtime.log";then exit 1;fi

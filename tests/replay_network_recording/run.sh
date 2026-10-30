#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_NETWORK_RECORDING_OUT:-$(mktemp -d)}";mkdir -p "$work"
trap 'echo "Network recording logs: $work"' EXIT
python3 "$ROOT/tests/replay_network_recording/prepare.py" "$work"
project="$work/project"
case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) exit 1;;esac
bash "$ROOT/build/build_scripts.sh" "$project" >"$work/build.log" 2>&1
ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext" "$GODOT" --headless --path "$project" --editor --quit-after 120 >"$work/import.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log";then tail -40 "$work/import.log";exit 1;fi
python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$project" "$work/build-wait.json"
bash "$ROOT/build/build_scripts.sh" "$project" >"$work/final-build.log" 2>&1
odin build "$ROOT/examples/replay_scrapyard/tools/verify_recording" -collection:godot="$ROOT" -out:"$work/verify_recording" >"$work/verify-build.log" 2>&1
python3 "$ROOT/tests/replay_network_recording/execute.py" "$work"
odin check "$project/scripts" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point -custom-attribute:gd_method -custom-attribute:gd_connect >"$work/wasm.log" 2>&1

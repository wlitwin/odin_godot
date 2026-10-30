#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="$1"
python3 "$ROOT/tests/replay_claimball_trace/legacy.py" "$work"
export ODIN_GODOT_ROOT="$work/collection"
bash "$ROOT/build/build_scripts.sh" "$work/project" >"$work/build.log" 2>&1
case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) exit 1;;esac
ODIN_SCRIPTS_DLL="$work/project/bin/libodinscripts.$ext" "$GODOT" --headless --path "$work/project" --editor --quit-after 120 >"$work/import.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log";then tail -40 "$work/import.log";exit 1;fi
python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$work/project" "$work/wait.json"
bash "$ROOT/build/build_scripts.sh" "$work/project" >"$work/final-build.log" 2>&1
odin build "$ROOT/tests/replay_claimball_trace/replay" -collection:godot="$ODIN_GODOT_ROOT" -out:"$work/replay-trace" >"$work/replayer-build.log" 2>&1
odin build "$ROOT/tests/replay_claimball_trace/replay" -collection:godot="$work/current-collection" -out:"$work/replay-current" >"$work/current-replayer-build.log" 2>&1

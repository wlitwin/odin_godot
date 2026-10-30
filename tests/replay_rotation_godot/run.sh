#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/tests/replay_rotation_godot";work="${REPLAY_ROTATION_GODOT_OUT:-$(mktemp -d)}";mkdir -p "$work"
trap 'echo "Rotation adapter logs: $work"' EXIT
bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/build.log" 2>&1
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
"$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log";then cat "$work/import.log";exit 1;fi
python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$PROJ" "$work/build-wait.json"
bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/final-build.log" 2>&1
"$GODOT" --headless --path "$PROJ" --quit-after 600 >"$work/run.log" 2>&1
cat "$work/run.log";rg -q REPLAY_ROTATION_GODOT_OK "$work/run.log"
if rg -q 'SCRIPT ERROR|ERROR:|instances were leaked|resources still in use|ROTATION_FAIL' "$work/run.log";then exit 1;fi
odin check "$PROJ/scripts" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point -custom-attribute:gd_method

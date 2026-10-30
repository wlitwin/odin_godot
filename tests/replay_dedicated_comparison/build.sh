#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT" SCRIPT_BUILD_FLAGS=-o:speed
work="$1";mkdir -p "$work"
python3 "$ROOT/tests/replay_dedicated_comparison/prepare.py" "$work" >"$work/prepare.log"
case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) exit 1;;esac
for impl in kit replay;do
 project="$work/$impl/project"
 bash "$ROOT/build/build_scripts.sh" "$project" >"$work/$impl/build.log" 2>&1
 ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext" "$GODOT" --headless --path "$project" --editor --quit-after 120 >"$work/$impl/import.log" 2>&1
 if rg -q 'SCRIPT ERROR|ERROR:' "$work/$impl/import.log";then tail -50 "$work/$impl/import.log";exit 1;fi
 python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$project" "$work/$impl/wait.json"
 bash "$ROOT/build/build_scripts.sh" "$project" >"$work/$impl/final-build.log" 2>&1
done

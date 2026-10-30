#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="$1";python3 "$ROOT/tests/replay_cave_comparison/prepare.py" "$work"
case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) exit 1;;esac
for variant in kit server owner;do
 project="$work/$variant/project"
 bash "$ROOT/build/build_scripts.sh" "$project" >"$work/$variant/build.log" 2>&1
 ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext" "$GODOT" --headless --path "$project" --editor --quit-after 120 >"$work/$variant/import.log" 2>&1
 if rg -q 'SCRIPT ERROR|ERROR:' "$work/$variant/import.log";then tail -40 "$work/$variant/import.log";exit 1;fi
 python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$project" "$work/$variant/wait.json"
 SCRIPT_BUILD_FLAGS='-o:speed' bash "$ROOT/build/build_scripts.sh" "$project" >"$work/$variant/final-build.log" 2>&1
done

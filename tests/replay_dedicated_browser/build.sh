#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="$1";mkdir -p "$work"
python3 "$ROOT/tests/replay_dedicated_browser/prepare.py" "$work"
case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) exit 1;;esac
for kind in game service;do
 project="$work/$kind/project"
 bash "$ROOT/build/build_scripts.sh" "$project" >"$work/$kind/build.log" 2>&1
 ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext" "$GODOT" --headless --path "$project" --editor --quit-after 120 >"$work/$kind/import.log" 2>&1
 if rg -q 'SCRIPT ERROR|ERROR:' "$work/$kind/import.log";then tail -40 "$work/$kind/import.log";exit 1;fi
 python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$project" "$work/$kind/wait.json"
 bash "$ROOT/build/build_scripts.sh" "$project" >"$work/$kind/final-build.log" 2>&1
done
project="$work/game/project"
ODIN_EXPORT_OPT=speed bash "$ROOT/build/build_web.sh" "$project" >"$work/game/web-build.log" 2>&1
mkdir -p "$project/out";touch "$project/out/.gdignore"
ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext" "$GODOT" --headless --path "$project" --export-release Web "$project/out/index.html" >"$work/game/export.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/game/export.log";then tail -40 "$work/game/export.log";exit 1;fi

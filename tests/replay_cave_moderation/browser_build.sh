#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="$1";python3 "$ROOT/tests/replay_cave_moderation/browser_prepare.py" "$work"
case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) exit 1;;esac
for kind in project server;do
 project="$work/$kind"
 bash "$ROOT/build/build_scripts.sh" "$project" >"$work/$kind-build.log" 2>&1
 ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext" "$GODOT" --headless --path "$project" --editor --quit-after 120 >"$work/$kind-import.log" 2>&1
 if rg -q 'SCRIPT ERROR|ERROR:' "$work/$kind-import.log";then tail -40 "$work/$kind-import.log";exit 1;fi
 python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$project" "$work/$kind-wait.json"
 bash "$ROOT/build/build_scripts.sh" "$project" >"$work/$kind-final-build.log" 2>&1
done
project="$work/project"
ODIN_EXPORT_OPT=speed bash "$ROOT/build/build_web.sh" "$project" >"$work/web-build.log" 2>&1
mkdir -p "$project/out";touch "$project/out/.gdignore"
ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext" "$GODOT" --headless --path "$project" --export-release Web "$project/out/index.html" >"$work/export.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/export.log";then tail -40 "$work/export.log";exit 1;fi

#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="$1";project="$work/project"
case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) exit 1;;esac
ODIN_EXPORT_OPT=speed bash "$ROOT/build/build_web.sh" "$project" >"$work/web-build.log" 2>&1
mkdir -p "$project/out";touch "$project/out/.gdignore"
ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext" "$GODOT" --headless --path "$project" --export-release Web "$project/out/index.html" >"$work/export.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/export.log";then tail -40 "$work/export.log";exit 1;fi

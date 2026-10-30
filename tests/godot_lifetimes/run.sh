#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/tests/godot_lifetimes";work="${GODOT_LIFETIMES_LOGS:-$(mktemp -d)}";mkdir -p "$work"
echo "Godot lifetime logs: $work"
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]];then bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/build.log" 2>&1;fi
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
"$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log";then cat "$work/import.log";exit 1;fi
"$GODOT" --headless --path "$PROJ" --quit-after 600 >"$work/run.log" 2>&1
cat "$work/run.log";rg -q GODOT_LIFETIMES_OK "$work/run.log"
if rg -q 'SCRIPT ERROR|ERROR:|instances were leaked|resources still in use' "$work/run.log";then exit 1;fi
odin check "$PROJ/scripts" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point -custom-attribute:gd_method

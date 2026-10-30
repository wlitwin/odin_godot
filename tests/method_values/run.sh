#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/tests/method_values"
work="${METHOD_VALUES_LOGS:-$(mktemp -d)}"
mkdir -p "$work"
echo "Method value logs: $work"
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]]; then bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/build.log" 2>&1; fi
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
"$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log"; then cat "$work/import.log"; exit 1; fi
result=0
"$GODOT" --headless --path "$PROJ" >"$work/runtime.log" 2>&1 || result=$?
cat "$work/runtime.log"
((result==0))
rg -q '^METHOD_VALUES_OK$' "$work/runtime.log"
if rg -q 'SCRIPT ERROR|ERROR:|instances were leaked|resources still in use' "$work/runtime.log"; then exit 1; fi

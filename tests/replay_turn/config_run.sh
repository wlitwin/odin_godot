#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/tests/replay_rtc";work="${REPLAY_ICE_CONFIG_OUT:-$(mktemp -d)}";mkdir -p "$work"
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/build.log" 2>&1
"$GODOT" --headless --path "$PROJ" --editor --quit-after 90 >"$work/import.log" 2>&1
python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$PROJ" "$work/wait.json"
"$GODOT" --headless --path "$PROJ" ice.tscn >"$work/run.log" 2>&1
cat "$work/run.log"
rg -q RTC_ICE_CONFIG_OK "$work/run.log"
if rg -q 'SCRIPT ERROR|ERROR:|RTC_ICE_FAIL|instances were leaked|resources still in use' "$work"/*.log;then exit 1;fi
odin check "$PROJ/scripts" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point -custom-attribute:gd_method
echo REPLAY_ICE_CONFIG_OK

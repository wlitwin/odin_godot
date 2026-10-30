#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_scrapyard";work="${REPLAY_WORKBENCH_OUT:-$(mktemp -d)}";mkdir -p "$work"
trap 'if [[ "${REPLAY_KEEP_LOGS:-0}" == 1 || -n "${REPLAY_WORKBENCH_OUT:-}" ]];then echo "Workbench logs: $work";else rm -rf "$work";fi' EXIT
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]];then
 bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/build.log" 2>&1
 "$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1
 if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log";then cat "$work/import.log";exit 1;fi
 python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$PROJ" "$work/build-wait.json"
 bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/final-build.log" 2>&1
fi
for scenario in panels boss wipe;do
 WB_CASE="$scenario" "$GODOT" --headless --max-fps 60 --path "$PROJ" --script workbench_test.gd >"$work/$scenario.log" 2>&1
 cat "$work/$scenario.log"
 rg -q "REPLAY_SCRAPYARD_WORKBENCH_OK case=$scenario" "$work/$scenario.log"
 if rg -q 'SCRIPT ERROR|ERROR:|WORKBENCH_FAIL|instances were leaked|resources still in use' "$work/$scenario.log";then exit 1;fi
done
echo REPLAY_WORKBENCH_OK

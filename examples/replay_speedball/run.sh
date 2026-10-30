#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_speedball"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]]; then
  bash "$ROOT/build/build_scripts.sh" "$PROJ"
  "$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1
  if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log"; then cat "$work/import.log"; exit 1; fi
  python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$PROJ" "$work/build-wait.json"
  bash "$ROOT/build/build_scripts.sh" "$PROJ"
fi

if ! RSB_ROLE=solo RSB_TOKEN=solo-gate RSB_BOT=striker RSB_GOALS=1 RSB_TEST=1 "$GODOT" --headless --path "$PROJ" >"$work/solo.log" 2>&1; then cat "$work/solo.log"; exit 1; fi
cat "$work/solo.log"
grep -q 'RSB_SCORE left=1 right=0 winner=1' "$work/solo.log"
grep -q REPLAY_SPEEDBALL_PROCESS_OK "$work/solo.log"
if grep -Eq 'SCRIPT ERROR|ERROR:|REPLAY_SPEEDBALL_FAIL|ObjectDB instances were leaked' "$work"/*.log; then exit 1; fi
echo REPLAY_SPEEDBALL_SOLO_OK

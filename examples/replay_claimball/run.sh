#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_claimball"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]]; then bash "$ROOT/build/build_scripts.sh" "$PROJ"; fi
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
if ! "$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1; then cat "$work/import.log"; exit 1; fi
if ! RCB_ROLE=solo RCB_BOT=striker RCB_GOALS=1 RCB_TEST=1 "$GODOT" --headless --path "$PROJ" >"$work/solo.log" 2>&1; then cat "$work/solo.log"; exit 1; fi
cat "$work/solo.log"
grep -q 'RCB_SCORE left=1 right=0 winner=1' "$work/solo.log"
grep -q REPLAY_CLAIMBALL_PROCESS_OK "$work/solo.log"
if grep -Eq 'SCRIPT ERROR|ERROR:|REPLAY_CLAIMBALL_FAIL|ObjectDB instances were leaked' "$work"/*.log; then exit 1; fi
echo REPLAY_CLAIMBALL_SOLO_OK

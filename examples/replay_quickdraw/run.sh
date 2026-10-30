#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/examples/replay_quickdraw"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]]; then bash "$ROOT/build/build_scripts.sh" "$PROJ"; fi
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
if ! "$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1; then cat "$work/import.log"; exit 1; fi
if ! RQ_ROLE=solo RQ_BOT=orbit RQ_GOLD=1 RQ_TEST_SECONDS=4 "$GODOT" --headless --path "$PROJ" >"$work/run.log" 2>&1; then cat "$work/run.log"; exit 1; fi
cat "$work/run.log"
grep -q 'RQ_RESULT .* buys=1' "$work/run.log"
grep -q REPLAY_QUICKDRAW_PROCESS_OK "$work/run.log"
if grep -Eq 'SCRIPT ERROR|ERROR:|REPLAY_QUICKDRAW_FAIL|ObjectDB instances were leaked' "$work"/*.log; then exit 1; fi
echo REPLAY_QUICKDRAW_SOLO_OK

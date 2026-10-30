#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_slopball"
work="$(mktemp -d)"
cleanup() { if [[ "${REPLAY_KEEP_LOGS:-0}" == 1 ]]; then echo "Replay Slopball logs: $work"; else rm -rf "$work"; fi; }
trap cleanup EXIT
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]]; then bash "$ROOT/build/build_scripts.sh" "$PROJ"; fi
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
if ! "$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1; then cat "$work/import.log"; exit 1; fi
if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log"; then cat "$work/import.log"; exit 1; fi
RSL_ROLE=solo RSL_TEST=1 RSL_BOT=striker RSL_PLAYERS=1 RSL_GOALS=1 "$GODOT" --headless --path "$PROJ" >"$work/game.log" 2>&1
cat "$work/game.log"
rg -q REPLAY_SLOPBALL_PEER_OK "$work/game.log"
if rg -q 'REPLAY_SLOPBALL_FAIL|SCRIPT ERROR|ERROR:|ObjectDB instances were leaked' "$work/game.log"; then exit 1; fi
echo REPLAY_SLOPBALL_SINGLE_OK

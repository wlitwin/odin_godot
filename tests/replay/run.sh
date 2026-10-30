#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
"${ODIN:-odin}" test "$ROOT/tests/replay" -collection:godot="$ROOT" -out:"$work/replay_tests"
# Instantiate the same timeline/game for web, including reflection and pools.
"${ODIN:-odin}" check "$ROOT/examples/replay_loot" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point
bash "$ROOT/examples/replay_loot/run.sh"
echo "REPLAY_OK"

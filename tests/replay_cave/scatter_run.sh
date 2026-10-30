#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="${REPLAY_SCATTER_OUT:-$(mktemp -d)}";mkdir -p "$work"
trap 'echo "Scatter logs: $work"' EXIT
python3 "$ROOT/tests/replay_cave/scatter_oracle.py" "$work/oracle"
odin build "$work/oracle" -out:"$work/original"
"$work/original" >"$work/original.txt"
odin build "$ROOT/tests/replay_cave/scatter_native" -collection:godot="$ROOT" -out:"$work/current"
"$work/current" >"$work/current.txt";cmp "$work/original.txt" "$work/current.txt"
odin build "$ROOT/tests/replay_cave/scatter_wasm" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point -out:"$work/scatter.wasm"
node "$ROOT/tests/replay_cave/scatter_compare.mjs" "$work/scatter.wasm" "$work/current.txt"
echo REPLAY_CAVE_SCATTER_OK

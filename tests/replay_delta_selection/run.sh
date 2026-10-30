#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="${REPLAY_DELTA_SELECTION_OUT:-$(mktemp -d)}";mkdir -p "$work"
trap 'echo "Delta selection logs: $work"' EXIT
for mode in default speed;do
 flags=();if [[ "$mode" == speed ]];then flags+=(-o:speed);fi
 odin build "$ROOT/tests/replay_delta_selection" -collection:godot="$ROOT" "${flags[@]}" -out:"$work/$mode"
 "$work/$mode" | tee "$work/$mode.log"
 odin build "$ROOT/tests/replay_delta_selection/wasm" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point "${flags[@]}" -out:"$work/$mode.wasm"
 node "$ROOT/tests/replay_delta_selection/check.mjs" "$work/$mode.wasm" "$work/$mode.log"
done
echo REPLAY_DELTA_SELECTION_OK

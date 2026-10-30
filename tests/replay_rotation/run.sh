#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="${REPLAY_ROTATION_OUT:-$(mktemp -d)}";mkdir -p "$work";trap 'echo "Rotation logs: $work"' EXIT
for mode in default speed;do
 flags=();if [[ "$mode" == speed ]];then flags+=(-o:speed);fi
 odin build "$ROOT/tests/replay_rotation" -collection:godot="$ROOT" "${flags[@]}" -out:"$work/$mode"
 "$work/$mode" >"$work/$mode.log";cat "$work/$mode.log"
 odin build "$ROOT/tests/replay_rotation/wasm" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point "${flags[@]}" -out:"$work/$mode.wasm"
 node "$ROOT/tests/replay_rotation/check.mjs" "$work/$mode.wasm"
done
echo REPLAY_ROTATION_OK

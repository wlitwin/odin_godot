#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="${REPLAY_REUSE_OUT:-$(mktemp -d)}";mkdir -p "$work"
for mode in default speed;do
 flags=();[[ "$mode" == speed ]] && flags=(-o:speed)
 odin build "$ROOT/tests/replay_correction_reuse" -collection:godot="$ROOT" "${flags[@]}" -out:"$work/$mode"
 "$work/$mode" | tee "$work/$mode.log"
 odin build "$ROOT/tests/replay_correction_reuse/wasm" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point "${flags[@]}" -out:"$work/$mode.wasm"
 node "$ROOT/tests/replay_correction_reuse/check.mjs" "$work/$mode.wasm" "$work/$mode.log"
done
echo REPLAY_CORRECTION_REUSE_OK

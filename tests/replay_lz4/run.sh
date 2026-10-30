#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="${REPLAY_LZ4_OUT:-$(mktemp -d)}";mkdir -p "$work";trap 'echo "LZ4 codec logs: $work"' EXIT
reference=();if [[ -n "${LZ4_LIB_DIR:-}" ]];then reference+=("-extra-linker-flags:-L$LZ4_LIB_DIR");fi
for mode in default speed;do
 flags=();if [[ "$mode" == speed ]];then flags+=(-o:speed);fi
 odin build "$ROOT/tests/replay_lz4" -collection:godot="$ROOT" "${reference[@]}" "${flags[@]}" -out:"$work/$mode"
 "$work/$mode" | tee "$work/$mode.log"
 odin build "$ROOT/tests/replay_lz4/wasm" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point "${flags[@]}" -out:"$work/$mode.wasm"
 node "$ROOT/tests/replay_lz4/check.mjs" "$work/$mode.wasm" "$work/$mode.log"
done
echo REPLAY_LZ4_OK

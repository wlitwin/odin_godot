#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";work="$(mktemp -d)";trap 'rm -rf "$work"' EXIT
odin test "$ROOT/tests/replay_compress" -collection:godot="$ROOT" -out:"$work/test"
echo REPLAY_COMPRESS_OK
for mode in default speed;do
 flags=();if [[ "$mode" == speed ]];then flags+=(-o:speed);fi
 odin build "$ROOT/tests/replay_compress/native" -collection:godot="$ROOT" "${flags[@]}" -out:"$work/$mode"
 "$work/$mode" | tee "$work/$mode.log"
 odin build "$ROOT/tests/replay_compress/wasm" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point "${flags[@]}" -out:"$work/$mode.wasm"
 node "$ROOT/tests/replay_compress/check.mjs" "$work/$mode.wasm" "$work/$mode.log"
done

#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="$1";mkdir -p "$work"
odin run "$ROOT/tests/replay_turret/native" -collection:godot="$ROOT" -o:speed -out:"$work/native" >"$work/native.log"
odin build "$ROOT/tests/replay_turret/wasm" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point -o:speed -build-mode:obj -out:"$work/turret.o"
emcc "$work/turret.o" --no-entry -sSTANDALONE_WASM=1 -sINITIAL_MEMORY=402653184 -sSTACK_SIZE=8388608 -O2 -o "$work/turret.wasm"
node "$ROOT/replay/testing/tools/wasm_equal.mjs" "$work/turret.wasm" "$work/native.log" verify TURRET_WASM_EQUAL

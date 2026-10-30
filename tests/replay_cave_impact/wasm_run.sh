#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="$1";mkdir -p "$work"
odin build "$ROOT/tests/replay_cave_impact/wasm" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point -build-mode:obj -out:"$work/verify.o"
emcc "$work/verify.o" --no-entry -sSTANDALONE_WASM=1 -sINITIAL_MEMORY=201326592 -sSTACK_SIZE=8388608 -O2 -o "$work/verify.wasm"
node "$ROOT/tests/replay_cave_impact/wasm_run.mjs" "$work/verify.wasm"

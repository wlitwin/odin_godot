#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="$1";shift;mkdir -p "$work"
odin build "$ROOT/tests/replay_claimball_trace/replay" -collection:godot="$ROOT" -out:"$work/replay-trace"
odin build "$ROOT/tests/replay_claimball_trace/wasm" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point -build-mode:obj -out:"$work/replay.o"
emcc "$work/replay.o" --no-entry -sSTANDALONE_WASM=1 -sINITIAL_MEMORY=201326592 -sSTACK_SIZE=8388608 -O2 -o "$work/replay.wasm"
node "$ROOT/tests/replay_claimball_trace/targets.mjs" "$work/replay.wasm" "$work/replay-trace" "$@" | tee "$work/targets.log"

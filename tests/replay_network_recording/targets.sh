#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="$1";shift;mkdir -p "$work"
legacy_flags=();if [[ "${REPLAY_RECORDING_CONTENT48:-0}" == 1 ]];then legacy_flags=(-define:REPLAY_RECORDING_CONTENT48=true);fi
odin build "$ROOT/examples/replay_scrapyard/tools/verify_recording" -collection:godot="$ROOT" -out:"$work/verify_recording"
odin build "$ROOT/tests/replay_network_recording/mutate" -collection:godot="$ROOT" -out:"$work/mutate" "${legacy_flags[@]}"
odin build "$ROOT/tests/replay_network_recording/wasm" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point -build-mode:obj -out:"$work/verify.o" "${legacy_flags[@]}"
# Link the same Emscripten single-precision math implementation used by the web
# game. The simulation must execute inside WASM, without JS sin/cos substitutes.
emcc "$work/verify.o" --no-entry -sSTANDALONE_WASM=1 -sINITIAL_MEMORY=201326592 -sSTACK_SIZE=8388608 -O2 -o "$work/verify.wasm"
node "$ROOT/tests/replay_network_recording/targets.mjs" "$work/verify.wasm" "$work/verify_recording" "$@" | tee "$work/targets.log"

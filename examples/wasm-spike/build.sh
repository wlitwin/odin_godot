#!/usr/bin/env bash
# Spike W — Odin -> Emscripten SIDE_MODULE wasm, the exact working command sequence.
#
# Run inside the Nix dev shell (from the repo root):
#   nix develop --command bash examples/wasm-spike/build.sh
#
# Produces examples/wasm-spike/spike.wasm and verifies add(2,3)==5 via node.
#
# NOTE: the shell's emscripten is 5.0.6. Godot 4.6.2 stable's web templates were
# built with emscripten 4.0.20 (see docs/wasm-spike.md). For a real Godot-web load
# the link step MUST be re-run under emscripten 4.0.20 to match the dynamic-linking
# / longjmp ABI. The mechanics below are version-independent.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

# (a) Odin -> wasm object. Freestanding wasm32, object output, no entry point.
#     "c"/exported procs keep unmangled, wasm-exported symbols.
odin build src \
    -target:freestanding_wasm32 \
    -build-mode:obj \
    -no-entry-point \
    -out:spike.wasm.o

# (b) Object -> Emscripten SIDE_MODULE. -sSUPPORT_LONGJMP=wasm is required by the
#     real binding (setjmp/longjmp -> invoke_* ABI); harmless for this leaf module.
emcc spike.wasm.o \
    -sSIDE_MODULE=1 \
    -sSUPPORT_LONGJMP=wasm \
    -O2 \
    -o spike.wasm

echo "Built $HERE/spike.wasm"
file spike.wasm

# (c) Verify: instantiate standalone and call the exported procs.
node inspect.mjs

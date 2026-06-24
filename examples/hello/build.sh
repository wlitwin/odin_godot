#!/usr/bin/env bash
# Build the OdinHello GDExtension dll into examples/hello/bin/.
# Run from anywhere; uses absolute collection path so imports resolve.
set -euo pipefail

ROOT="/Users/walter/data/code/odin/odin_godot"
SRC="$ROOT/examples/hello/src"
OUT="$ROOT/examples/hello/bin/hello.dylib"

mkdir -p "$ROOT/examples/hello/bin"

odin build "$SRC" \
    -collection:godot="$ROOT" \
    -build-mode:dll \
    -out:"$OUT" \
    -debug

echo "Built $OUT"

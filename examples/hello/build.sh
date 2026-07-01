#!/usr/bin/env bash
# Build the OdinHello GDExtension dll into examples/hello/bin/.
# Run from anywhere; uses absolute collection path so imports resolve.
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SRC="$ROOT/examples/hello/src"
OUT="$ROOT/examples/hello/bin/hello.dylib"

mkdir -p "$ROOT/examples/hello/bin"

odin build "$SRC" \
    -collection:godot="$ROOT" \
    -build-mode:dll \
    -out:"$OUT" \
    -debug

echo "Built $OUT"

#!/usr/bin/env bash
# Build the odin_godot core GDExtension dll into tests/phase1/bin/.
# Run from anywhere; uses absolute collection path so imports resolve.
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SRC="$ROOT/core"
OUT="$ROOT/tests/phase1/bin/libodin_godot.dylib"

mkdir -p "$ROOT/tests/phase1/bin"

# Remove prior outputs first: a stale dll / intermediate `.o` built against an OLD
# runtime layout (e.g. a changed Class_Desc) can survive an incremental `-out:` build and
# crash at extension init. A clean output guarantees the dll matches the current sources.
rm -f "$OUT" "$ROOT"/tests/phase1/bin/libodin_godot-*.o

odin build "$SRC" \
    -collection:godot="$ROOT" \
    -build-mode:dll \
    -out:"$OUT" \
    -debug

echo "Built $OUT"

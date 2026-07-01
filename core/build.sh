#!/usr/bin/env bash
# Build the odin_godot core GDExtension dll into tests/phase1/bin/.
# Run from anywhere; uses absolute collection path so imports resolve.
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SRC="$ROOT/core"
OUT="$ROOT/tests/phase1/bin/libodin_godot.dylib"

# Shared helpers: $ODIN override + atomic_odin_dll (temp+mv publish, stale-.o scrub).
source "$ROOT/build/common.sh"

mkdir -p "$ROOT/tests/phase1/bin"

# Scrub intermediates from OLD non-atomic builds: a stale `.o` built against an old
# runtime layout (e.g. a changed Class_Desc) can survive an incremental `-out:` build and
# crash at extension init. (atomic_odin_dll scrubs its OWN temp intermediates; this line
# covers the legacy `libodin_godot-*.o` names earlier versions of this script left behind.)
rm -f "$ROOT"/tests/phase1/bin/libodin_godot-*.o

# temp+mv publish: never build over the live dll, so an interrupted/failed build leaves
# the previously-built dll loadable instead of a truncated half-write.
atomic_odin_dll "$SRC" "$OUT" -debug

echo "Built $OUT"

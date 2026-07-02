#!/usr/bin/env bash
# Barrage — the data-oriented showcase, end-to-end: multi-module build (main + 4 module
# dlls), then a headless run of the REAL game loop asserting: thousands of live SOA/
# multimesh bullets, the field->player hit path, a powerup taking effect, the boss's
# three flow phases, and score. Prints BARRAGE_OK.
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/examples/barrage"

bash "$ROOT/build/build_scripts.sh" "$PROJ"
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"
for m in barrage enemies powerups ui; do
    ls "$PROJ/bin/libodinscripts_${m}."* >/dev/null 2>&1 || { echo "BARRAGE_FAIL: module dll for '$m' missing"; exit 1; }
done
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

OUT="$(BARRAGE_TEST=1 "$GODOT" --headless --path "$PROJ" --script test_barrage.gd 2>&1 || true)"
echo "$OUT" | grep -E "BARRAGE_" || true
echo "$OUT" | grep -q "BARRAGE_OK"

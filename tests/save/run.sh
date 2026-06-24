#!/usr/bin/env bash
# Saver regression — ResourceSaver.save() must write a .odin script to disk (OdinResourceFormatSaver).
# Reuses the showcase project's built dlls. Prints SAVE_TEST_OK.
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/tests/showcase"
bash "$ROOT/build/build_scripts.sh" "$PROJ"
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true
OUT="$("$GODOT" --headless --path "$PROJ" --script test_save.gd 2>&1 || true)"
echo "$OUT" | grep -E "SAVE_TEST_OK|SAVE_TEST_FAIL" || true
echo "$OUT" | grep -q "SAVE_TEST_OK"

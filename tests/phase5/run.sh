#!/usr/bin/env bash
# Phase 5 firm milestone — native desktop export on the current host.
#
# Proves an EXPORTED game (not the editor) loads the odin_godot extension and runs an
# Odin script that was COMPILED AT EXPORT TIME by OdinExportPlugin. End to end:
#   1. Build the core dll (with the export plugin) into the project's bin/.
#   2. Export the host preset. OdinExportPlugin compiles and bundles the scripts
#      library beside the auto-exported core.
#   3. Run the exported game headless and assert its Odin `_ready` sentinels.
# Prints PHASE5_OK on success. Run inside the Nix dev shell:
#   nix develop --command bash -c 'bash tests/phase5/run.sh'
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "$ROOT/tests/platform.sh"
export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/tests/phase5"
odin_godot_test_export_paths "$PROJ" OdinGamePhase5 OdinGodotPhase5
EXE="$ODIN_GODOT_TEST_EXPORTED_EXE"
EXPORT_LOG="$(mktemp)"
trap 'rm -f "$EXPORT_LOG"' EXIT

# 1. Build the CORE dll into the project bin (the scripts dll is rebuilt by the plugin
#    at export). This also runs scriptgen so res://scripts/odin_godot_scripts.gen.odin exists; the
#    scene attaches the authored res://scripts/main.odin directly (single-file).
bash "$ROOT/build/build_scripts.sh" "$PROJ" >/dev/null 2>&1

# Import so the editor writes .godot/extension_list.cfg (extension loads on export).
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

# 2. Headless export. The export plugin compiles + bundles the scripts dll.
rm -rf "$PROJ/out"
mkdir -p "$PROJ/out"
if ! "$GODOT" --headless --path "$PROJ" --export-release "$ODIN_GODOT_TEST_EXPORT_PRESET" "$ODIN_GODOT_TEST_EXPORT_PATH" >"$EXPORT_LOG" 2>&1; then
    cat "$EXPORT_LOG"
    echo "PHASE5_FAIL: native export failed"
    exit 1
fi
grep -E "odin export:" "$EXPORT_LOG" || true

if [[ ! -x "$EXE" ]]; then
    echo "PHASE5_FAIL: exported executable missing ($EXE)"
    exit 1
fi
if [[ ! -f "$ODIN_GODOT_TEST_EXPORTED_LIBDIR/libodinscripts.$ODIN_GODOT_TEST_LIB_EXT" ]]; then
    echo "PHASE5_FAIL: scripts library not bundled beside the exported core"
    exit 1
fi
if [[ ! -f "$ODIN_GODOT_TEST_EXPORTED_LIBDIR/libodin_godot.$ODIN_GODOT_TEST_LIB_EXT" ]]; then
    echo "PHASE5_FAIL: core library not bundled into the native export"
    exit 1
fi

# 3. Run the EXPORTED binary headless and assert the Odin script ran.
OUT="$("$EXE" --headless --quit-after 120 2>&1 || true)"
if grep -q "EXPORT_RAN" <<<"$OUT" && grep -q "EXPORT_ASSERT_OK" <<<"$OUT"; then
    echo "native export ran Odin: EXPORT_RAN + EXPORT_ASSERT_OK"
    echo "PHASE5_OK"
else
    echo "PHASE5_FAIL: exported binary did not print the Odin sentinels"
    echo "----- output -----"
    echo "$OUT" | grep -vE "could not find symbol|^warning" | tail -20
    exit 1
fi

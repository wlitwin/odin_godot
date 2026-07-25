#!/usr/bin/env bash
# Phase 5 firm milestone — NATIVE DESKTOP EXPORT (macOS).
#
# Proves an EXPORTED game (not the editor) loads the odin_godot extension and runs an
# Odin script that was COMPILED AT EXPORT TIME by OdinExportPlugin. End to end:
#   1. Build the core dll (with the export plugin) into the project's bin/.
#   2. Headless export the macOS preset. OdinExportPlugin._export_begin compiles the
#      scripts dll for the target and add_shared_object's it into Contents/Frameworks,
#      beside the auto-exported core dll.
#   3. Run the exported .app headless; assert the Odin `_ready` sentinels printed.
# Prints PHASE5_OK on success. Run inside the Nix dev shell:
#   nix develop --command bash -c 'bash tests/phase5/run.sh'
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/tests/phase5"
APP="$PROJ/out/OdinGamePhase5.app"
EXE="$APP/Contents/MacOS/OdinGodotPhase5"

# 1. Build the CORE dll into the project bin (the scripts dll is rebuilt by the plugin
#    at export). This also runs scriptgen so res://scripts/odin_godot_scripts.gen.odin exists; the
#    scene attaches the authored res://scripts/main.odin directly (single-file).
bash "$ROOT/build/build_scripts.sh" "$PROJ" >/dev/null 2>&1

# Import so the editor writes .godot/extension_list.cfg (extension loads on export).
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

# 2. Headless export. The export plugin compiles + bundles the scripts dll.
rm -rf "$PROJ/out"
mkdir -p "$PROJ/out"
"$GODOT" --headless --path "$PROJ" --export-release "macOS" "$APP" 2>&1 \
    | grep -E "odin export:" || true

if [[ ! -x "$EXE" ]]; then
    echo "PHASE5_FAIL: exported executable missing ($EXE)"
    exit 1
fi
if [[ ! -f "$APP/Contents/Frameworks/libodinscripts.dylib" ]]; then
    echo "PHASE5_FAIL: scripts dll not bundled into Frameworks"
    exit 1
fi
if [[ ! -f "$APP/Contents/Frameworks/libodin_godot.dylib" ]]; then
    echo "PHASE5_FAIL: core dll not bundled into Frameworks"
    exit 1
fi

# 3. Run the EXPORTED binary headless and assert the Odin script ran.
OUT="$("$EXE" --headless --quit-after 120 2>&1 || true)"
if grep -q "EXPORT_RAN" <<<"$OUT" && grep -q "EXPORT_ASSERT_OK" <<<"$OUT"; then
    echo "exported .app ran Odin: EXPORT_RAN + EXPORT_ASSERT_OK"
    echo "PHASE5_OK"
else
    echo "PHASE5_FAIL: exported binary did not print the Odin sentinels"
    echo "----- output -----"
    echo "$OUT" | grep -vE "could not find symbol|^warning" | tail -20
    exit 1
fi

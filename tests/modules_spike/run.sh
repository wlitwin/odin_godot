#!/usr/bin/env bash
# Build + run the MULTI-MODULE scripts spike test. Greps for MODULES_SPIKE_OK.
# Run inside the Nix dev shell:
#   nix develop --command bash -c 'bash tests/modules_spike/run.sh'
#
# Four phases:
#   1. MAIN     — test_modules.gd: both modules attach + lifecycle; cross-module call
#                 via the engine; script_of module-local semantics; PER-MODULE reload
#                 (enemies v2 swap with the main module provably untouched).
#   2. COLLISION— a generated modules/rogue declares class Player (colliding with the
#                 main module): the core must reject the module with an error naming
#                 BOTH modules, while main's Player keeps working.
#   3. ISOLATION— a generated modules/sneak `import "../enemies"`: the build must FAIL
#                 with the ILLEGAL cross-module import message (globals-fork hazard).
#   4. EXPORT   — headless macOS export (phase5 pattern): the export plugin must build
#                 + bundle the MODULE dll beside the main scripts dll, and the exported
#                 app must run a module class. Prints MODULES_EXPORT_OK, then the suite
#                 sentinel MODULES_SPIKE_OK.
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/tests/modules_spike"
# The export phase runs the headless EDITOR, whose OdinExportPlugin resolves the
# collection root from the `odin_godot/root` setting -> ODIN_GODOT_ROOT env -> dladdr
# derivation. The test project keeps no root setting (it must work from any checkout),
# so export the env for the editor child — exactly what tests/run_all.sh does suite-wide.
export ODIN_GODOT_ROOT="$ROOT"

# Clean any leftovers from an aborted earlier run (the rogue/sneak modules are
# GENERATED here; they must never be present for phase 1).
cleanup_generated() {
    rm -rf "$PROJ/modules/rogue" "$PROJ/modules/sneak" \
        "$PROJ/bin/libodinscripts_rogue".* "$PROJ/bin/libodinscripts_sneak".* 2>/dev/null || true
}
cleanup_generated
LOG="$(mktemp)"
TLOG="$(mktemp)"
CLOG="$(mktemp)"
ILOG="$(mktemp)"
trap 'rm -f "$LOG" "$TLOG" "$CLOG" "$ILOG"; cleanup_generated' EXIT

# Build core + the main module + the enemies module (v1).
bash "$ROOT/build/build_scripts.sh" "$PROJ"

# Make the MAIN scripts dll path unambiguous for the core's dynlib load; the module
# dlls are discovered as its libodinscripts_<name> siblings.
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"

# First pass: write .godot/extension_list.cfg so the runtime loads the extension.
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

# ---- targeted scan: an enemies save must select only the enemies source tree ----
# Opt-in worker diagnostics expose the scan plan chosen before any filesystem walk. Ignore the
# initial all-module baseline; between the request/OK markers every plan must stay targeted.
export ODIN_RELOAD_TRACE_SCANS=1
"$GODOT" --editor --headless --path "$PROJ" --script test_targeted_scan.gd 2>&1 | tee "$TLOG"
TRC=${PIPESTATUS[0]}
unset ODIN_RELOAD_TRACE_SCANS
if [ "$TRC" -ne 0 ] || ! grep -q "TARGETED_MODULE_SCAN_OK" "$TLOG"; then
    echo "MODULES_SPIKE_FAIL: editor save did not remain scoped to the enemies module"
    exit 1
fi
TARGET_TRACE="$(awk '/TARGETED_SCAN_REQUEST/{capture=1; next} /TARGETED_MODULE_SCAN_OK/{capture=0} capture && /ODIN_RELOAD_SCAN_SCOPE/{print}' "$TLOG")"
if ! grep -q "ODIN_RELOAD_SCAN_SCOPE module=enemies" <<<"$TARGET_TRACE"; then
    echo "MODULES_SPIKE_FAIL: enemies save did not select the enemies scan scope"
    exit 1
fi
if grep -q "ODIN_RELOAD_SCAN_SCOPE all reason=bulk" <<<"$TARGET_TRACE"; then
    echo "MODULES_SPIKE_FAIL: enemies save fell back to a bulk all-module source scan"
    exit 1
fi
echo "  ok  editor save hashes/builds only its owning module"
# The driver restores enemy.odin before exiting; rebuild that module once so the on-disk
# DLL and restored authored layout are coherent for the existing runtime phase below.
SKIP_CORE=1 BUILD_MODULES=0 bash "$ROOT/build/build_scripts.sh" "$PROJ" "$PROJ/modules/enemies"

# ---- phase 1: main ----
"$GODOT" --headless --path "$PROJ" --script test_modules.gd 2>&1 | tee "$LOG"
RC=${PIPESTATUS[0]}
if [ "$RC" -ne 0 ]; then
    echo "MODULES_SPIKE_FAIL: main phase exited non-zero ($RC)"
    exit 1
fi
if ! grep -q "MODULES_SPIKE_MAIN_OK" "$LOG"; then
    echo "MODULES_SPIKE_FAIL: main phase did not print MODULES_SPIKE_MAIN_OK"
    exit 1
fi
if ! grep -q "ENEMY_RELOAD_FIRED" "$LOG"; then
    echo "MODULES_SPIKE_FAIL: the enemies module's reload hook did not fire on its swap"
    exit 1
fi
if grep -q "PLAYER_RELOAD_FIRED" "$LOG"; then
    echo "MODULES_SPIKE_FAIL: the MAIN module's reload hook fired — it was NOT left untouched"
    exit 1
fi
echo "  ok  per-module reload: enemies hook fired, player hook did not"
grep "MODULE_REBUILD_SECONDS" "$LOG" || true

# ---- phase 2: class-name collision across modules ----
mkdir -p "$PROJ/modules/rogue"
cat > "$PROJ/modules/rogue/rogue.odin" <<'EOF'
//gd:extends Node
//gd:class Player
package spike_rogue

// GENERATED BY run.sh (collision phase) — a module whose class name collides with the
// MAIN module's Player. The core must reject this module at load, loudly.

import gd "godot:godot"

Player :: struct {
	owner: gd.Node,
}

@(gd_method)
player_rogue_brand :: proc(self: ^Player) -> int {
	return -1
}
EOF
SKIP_CORE=1 BUILD_MODULES=0 bash "$ROOT/build/build_scripts.sh" "$PROJ" "$PROJ/modules/rogue"
"$GODOT" --headless --path "$PROJ" --script test_collision.gd 2>&1 | tee "$CLOG"
if ! grep -q "COLLISION_PHASE_OK" "$CLOG"; then
    echo "MODULES_SPIKE_FAIL: collision phase (main Player did not survive the colliding module)"
    exit 1
fi
if ! grep -q "is defined in BOTH script module" "$CLOG"; then
    echo "MODULES_SPIKE_FAIL: the collision was not surfaced with an error naming both modules"
    exit 1
fi
echo "  ok  class collision rejected loudly, naming both modules"
rm -rf "$PROJ/modules/rogue" "$PROJ/bin/libodinscripts_rogue".*

# ---- phase 3: cross-module import is a build error ----
mkdir -p "$PROJ/modules/sneak"
cat > "$PROJ/modules/sneak/sneak.odin" <<'EOF'
package spike_sneak

// GENERATED BY run.sh (isolation phase) — an ILLEGAL cross-module import. Odin itself
// would compile this (duplicating the enemies package's globals into this dll); the
// build script must reject it.

import en "../enemies"

sneak_probe :: proc() -> int {
	return en.STEP
}
EOF
if SKIP_CORE=1 BUILD_MODULES=0 bash "$ROOT/build/build_scripts.sh" "$PROJ" "$PROJ/modules/sneak" >"$ILOG" 2>&1; then
    echo "MODULES_SPIKE_FAIL: a cross-module import was NOT rejected by the build"
    cat "$ILOG"
    exit 1
fi
if ! grep -q "ILLEGAL cross-module import" "$ILOG"; then
    echo "MODULES_SPIKE_FAIL: cross-module import failed the build but without the clear message:"
    cat "$ILOG"
    exit 1
fi
echo "  ok  cross-module import rejected at build time with a clear message"

# ---- phase 4: NATIVE EXPORT bundles + runs ALL module dlls ----
# The generated sneak module from phase 3 is still on disk (the trap removes it at
# exit); it MUST be gone before exporting or the export build fails its isolation check.
cleanup_generated

APP="$PROJ/out/OdinGameModulesSpike.app"
EXE="$APP/Contents/MacOS/OdinGodotModulesSpike"
rm -rf "$PROJ/out" "$PROJ/.export_build"
mkdir -p "$PROJ/out"
"$GODOT" --headless --path "$PROJ" --export-release "macOS" "$APP" 2>&1 \
    | grep -E "odin export:" || true

if [[ ! -x "$EXE" ]]; then
    echo "MODULES_SPIKE_FAIL: exported executable missing ($EXE)"
    exit 1
fi
if [[ ! -f "$APP/Contents/Frameworks/libodinscripts.dylib" ]]; then
    echo "MODULES_SPIKE_FAIL: main scripts dll not bundled into Frameworks"
    exit 1
fi
if [[ ! -f "$APP/Contents/Frameworks/libodinscripts_enemies.dylib" ]]; then
    echo "MODULES_SPIKE_FAIL: enemies MODULE dll not bundled into Frameworks"
    exit 1
fi
echo "  ok  export bundled BOTH dlls (libodinscripts + libodinscripts_enemies)"

# Run the EXPORTED app headless. ODIN_SCRIPTS_DLL (exported above for the editor
# phases) must NOT leak in — the exported core must find its dlls INSIDE the bundle.
EOUT="$(env -u ODIN_SCRIPTS_DLL "$EXE" --headless --quit-after 120 2>&1 || true)"
if ! grep -q "EXPORT_MODULE_ENEMY_RAN" <<<"$EOUT" || ! grep -q "MODULES_EXPORT_ASSERT_OK" <<<"$EOUT"; then
    echo "MODULES_SPIKE_FAIL: exported app did not print the module sentinels"
    echo "----- output -----"
    grep -vE "could not find symbol|^warning" <<<"$EOUT" | tail -20
    exit 1
fi
echo "  ok  exported app ran a MODULE class: EXPORT_MODULE_ENEMY_RAN + MODULES_EXPORT_ASSERT_OK"
echo "MODULES_EXPORT_OK"

echo "MODULES_SPIKE_OK"

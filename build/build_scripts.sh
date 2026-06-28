#!/usr/bin/env bash
# Build the Phase 3.5 dlls via the codegen pipeline:
#   1. build the `scriptgen` preprocessor
#   2. run it over the scripts dir to emit `*.gen.odin` build artifacts
#   3. build the scripts dll (nice-form sources + generated *.gen.odin together)
#   4. build the core ScriptLanguageExtension dll
#
# SINGLE-FILE: the authored `res://scripts/*.odin` are themselves the resources attached
# to nodes (the loader binds them via their `//gd:class` marker); no resource stubs.
#
# Generalizes build/build_phase3.sh. Run inside the Nix dev shell, e.g.:
#   nix develop --command bash -c 'bash build/build_scripts.sh'
#
# Args: optional scripts dir + project dir (defaults to the phase35 test).
set -euo pipefail

# Repo root: derive from this script's location (build/ -> repo root), overridable via
# ODIN_GODOT_ROOT so the repo is not tied to one user's checkout path.
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PROJ="${1:-$ROOT/tests/phase35}"
SCRIPTS="${2:-$PROJ/scripts}"
BIN="$PROJ/bin"
mkdir -p "$BIN"

# Actionable failure when there are no scripts to compile (the #1 first-run snag): odin_godot
# ships the engine CORE prebuilt — your .odin gameplay scripts are YOURS and live in a
# scripts/ folder you create. Point the user at the bundled starter (which also carries the
# REQUIRED boot.odin boilerplate) instead of dying inside scriptgen/odin with a vague error.
if [ ! -d "$SCRIPTS" ] || [ -z "$(ls "$SCRIPTS"/*.odin 2>/dev/null)" ]; then
    echo "build_scripts: no Odin scripts found at '$SCRIPTS'." >&2
    echo "  odin_godot ships the engine core; your .odin scripts are yours and go in a" >&2
    echo "  scripts/ folder. A scripts package also needs a boot.odin (required boilerplate)." >&2
    echo "  Quick start: copy the bundled template into place, then re-run:" >&2
    echo "    cp -r \"$ROOT/template/scripts\" \"$PROJ/scripts\"   # boot.odin + a Hello example" >&2
    echo "  (in the addon, the template is at addons/odin_godot/template/ — see its README.md)" >&2
    exit 1
fi

# The `odin` compiler. Overridable via env so callers that resolved an absolute compiler
# path (e.g. the editor reload-on-save coordinator, which can't rely on `odin` being on the
# editor's PATH) can pass it through as `ODIN=/abs/path/to/odin`.
ODIN="${ODIN:-odin}"

# 1. Build the codegen preprocessor itself.
"$ODIN" build "$ROOT/scriptgen" \
    -collection:godot="$ROOT" \
    -out:"$ROOT/scriptgen/scriptgen" \
    -debug

# 2. Generate the *.gen.odin siblings beside the authored sources.
"$ROOT/scriptgen/scriptgen" "$SCRIPTS"

# 3. Build the scripts dll. The *.gen.odin live in the same package and compile
#    together. `-custom-attribute:gd_method` lets authors mark methods with
#    `@(gd_method)` (the codegen marker for GDScript-callable procs).
#    `SCRIPT_BUILD_FLAGS` (env, optional) forwards extra odin flags to the scripts
#    dll build ONLY — e.g. `-define:RELOAD_V=2` to build a v2 for the Phase 4 reload
#    test without rebuilding the core. `SKIP_CORE=1` skips step 4 (a reload rebuild
#    only needs a fresh scripts dll).
# Build to a TEMP output, then atomically `mv` it into place. `odin build -out:X` is NOT
# atomic — it truncates/creates X up front and writes over several seconds; and a fresh
# build needs a clean output anyway (a stale `.o` built against an OLD runtime layout can
# survive an incremental `-out:` build and crash at extension init). Building to a temp and
# publishing with `mv` gives BOTH: a clean output AND the invariant that the live
# `libodinscripts.dylib` is NEVER missing/half-written. This is the macOS packaging fix:
# the editor's reload-on-save coordinator (core/reload.odin) kicks THIS script on a worker
# thread when the project is opened/imported; if that build is interrupted (the editor
# quits / the headless import exits) or fails, the OLD non-destructive behavior left
# res://bin with NO scripts dll, so the core's next load printed "failed to load scripts
# dll" and the scene hit "No loader found". With atomic publish, an interrupted/failed
# build simply leaves the previously-built dll in place. (Mirrored in build_scripts.ps1.)
TMP_SCR="$BIN/.libodinscripts.tmp.dylib"
rm -f "$TMP_SCR" "$BIN"/.libodinscripts.tmp-*.o
"$ODIN" build "$SCRIPTS" \
    -collection:godot="$ROOT" \
    -build-mode:dll \
    -custom-attribute:gd_method -custom-attribute:gd_connect -custom-attribute:gd_rpc \
    -out:"$TMP_SCR" \
    -extra-linker-flags:"-Wl,-install_name,$BIN/libodinscripts.dylib" \
    -debug ${SCRIPT_BUILD_FLAGS:-}
# Reached only if the build succeeded (set -e). Publish atomically + move the matching
# .dSYM into place; the dylib loads by absolute path so its LC_ID_DYLIB (the tmp name) is
# never used for resolution.
rm -rf "$BIN/libodinscripts.dylib.dSYM"
[ -d "$TMP_SCR.dSYM" ] && mv -f "$TMP_SCR.dSYM" "$BIN/libodinscripts.dylib.dSYM"
mv -f "$TMP_SCR" "$BIN/libodinscripts.dylib"
rm -f "$BIN"/.libodinscripts.tmp-*.o

if [[ "${SKIP_CORE:-0}" == "1" ]]; then
    echo "Built (scripts only):"
    echo "  $BIN/libodinscripts.dylib"
    exit 0
fi

# 4. Build the core ScriptLanguageExtension dll (same atomic temp+mv publish as the scripts
#    dll above, so a failed/interrupted core build never deletes the live core dll either).
TMP_CORE="$BIN/.libodin_godot.tmp.dylib"
rm -f "$TMP_CORE" "$BIN"/.libodin_godot.tmp-*.o
"$ODIN" build "$ROOT/core" \
    -collection:godot="$ROOT" \
    -build-mode:dll \
    -out:"$TMP_CORE" \
    -extra-linker-flags:"-Wl,-install_name,$BIN/libodin_godot.dylib" \
    -debug
rm -rf "$BIN/libodin_godot.dylib.dSYM"
[ -d "$TMP_CORE.dSYM" ] && mv -f "$TMP_CORE.dSYM" "$BIN/libodin_godot.dylib.dSYM"
mv -f "$TMP_CORE" "$BIN/libodin_godot.dylib"
rm -f "$BIN"/.libodin_godot.tmp-*.o

echo "Built:"
echo "  $BIN/libodin_godot.dylib"
echo "  $BIN/libodinscripts.dylib"

#!/usr/bin/env bash
# Build the Phase 3.5 dlls via the codegen pipeline:
#   1. build the `scriptgen` preprocessor
#   2. run it over the scripts dir to emit its `*.gen.odin` build artifacts
#   3. build the scripts dll (nice-form sources + the generated *.gen.odin together)
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
# Shared helpers: ODIN/ODIN_GD_ATTRS/DLL_EXT, build_scriptgen/run_scriptgen,
# atomic_odin_dll (temp-build + atomic mv publish). Sourced from beside THIS script so
# an ODIN_GODOT_ROOT override can't point at a tree with a mismatched helper version.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
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

# 1. Build the codegen preprocessor itself — to a writable TEMP dir, NOT into the addon
#    (see build_scriptgen in build/common.sh; SGEN_BIN env reuses a prebuilt one).
build_scriptgen

# ---------------------------------------------------------------------------
# Multi-module support (spike). A project may split its scripts into MODULES:
#   res://scripts             -> libodinscripts.$DLL_EXT           (the MAIN module)
#   res://modules/<name>      -> libodinscripts_<name>.$DLL_EXT    (one dll per module)
# Each module is its OWN Odin package compiled STANDALONE. Saving in one module
# rebuilds only that module's dll (the reload coordinator passes the one dir here
# with BUILD_MODULES=0). A project without a modules/ dir behaves exactly as before.
# ---------------------------------------------------------------------------

# Map a scripts dir to its output dll leaf name.
dll_leaf_for_dir() {
    local dir="$1" name parent
    name="$(basename "$dir")"
    parent="$(basename "$(dirname "$dir")")"
    if [[ "$parent" == "modules" ]]; then
        echo "libodinscripts_${name}.$DLL_EXT"
    else
        echo "libodinscripts.$DLL_EXT"
    fi
}

# HARD RULE: no imports between script modules — enforced by check_module_isolation,
# which lives in build/common.sh (shared with build_export_scripts.sh; scriptgen adds
# the structural AST-level check on top). See its comment there for the why.

# scriptgen + odin build one scripts dir into its dll (atomic temp+mv publish — see
# atomic_odin_dll in common.sh: the live dll is NEVER missing/half-written even if the
# editor's reload-on-save coordinator is interrupted mid-build, and every publish is a
# clean build with no stale .o against an old runtime layout). ODIN_GD_ATTRS lets
# authors mark procs with @(gd_method) etc.; SCRIPT_BUILD_FLAGS (env, optional)
# forwards extra odin flags to the scripts builds ONLY — e.g. `-define:RELOAD_V=2`.
BUILT_DLLS=()
build_one_scripts_dir() {
    local dir="$1" out
    check_module_isolation "$dir"
    run_scriptgen "$dir"
    out="$BIN/$(dll_leaf_for_dir "$dir")"
    atomic_odin_dll "$dir" "$out" \
        ${ODIN_GD_ATTRS[@]+"${ODIN_GD_ATTRS[@]}"} \
        -debug ${SCRIPT_BUILD_FLAGS:-}
    BUILT_DLLS+=("$out")
}

# 2+3. Build the requested scripts dir; when it is the MAIN one, also build each
#      res://modules/<name> (BUILD_MODULES=0 opts out — the per-module reload rebuild
#      passes exactly one dir per invocation and must not chain the others).
build_one_scripts_dir "$SCRIPTS"
case "$SCRIPTS" in
    */modules/*) IS_MODULE_DIR=1 ;;
    *)           IS_MODULE_DIR=0 ;;
esac
if [[ "$IS_MODULE_DIR" == "0" && "${BUILD_MODULES:-1}" != "0" && -d "$PROJ/modules" ]]; then
    for mdir in "$PROJ/modules"/*/; do
        mdir="${mdir%/}"
        [ -d "$mdir" ] || continue
        if [ -z "$(ls "$mdir"/*.odin 2>/dev/null)" ]; then
            # Shared phrasing with build_export_scripts.sh / build_scripts.ps1 —
            # docs/modules.md quotes this exact string.
            echo "build_scripts: skipping module '$(basename "$mdir")' (no .odin sources)" >&2
            continue
        fi
        build_one_scripts_dir "$mdir"
    done
fi

if [[ "${SKIP_CORE:-0}" == "1" ]]; then
    echo "Built (scripts only):"
    for d in "${BUILT_DLLS[@]}"; do echo "  $d"; done
    exit 0
fi

# 4. Build the core ScriptLanguageExtension dll (same atomic temp+mv publish as the scripts
#    dlls above, so a failed/interrupted core build never deletes the live core dll either).
# CONSUMER LAYOUT: an addon install's .gdextension loads the core from
# addons/odin_godot/bin/<platform>/ — a core built to the project's bin/ is
# dead weight there (a fixed core "didn't take" for a full debugging hour).
# Publish the core where the manifest actually points.
CORE_DLL="$BIN/libodin_godot.$DLL_EXT"
if [[ "$ROOT" == */addons/odin_godot ]]; then
    case "$DLL_EXT" in
        dylib) CORE_PLAT=macos ;;
        so)    CORE_PLAT=linux ;;
        dll)   CORE_PLAT=windows ;;
        *)     CORE_PLAT="" ;;
    esac
    if [[ -n "$CORE_PLAT" ]]; then
        mkdir -p "$ROOT/bin/$CORE_PLAT"
        CORE_DLL="$ROOT/bin/$CORE_PLAT/libodin_godot.$DLL_EXT"
    fi
fi
atomic_odin_dll "$ROOT/core" "$CORE_DLL" -debug

echo "Built:"
echo "  $CORE_DLL"
for d in "${BUILT_DLLS[@]}"; do echo "  $d"; done

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

# 2. Generate the *.gen.odin siblings beside the authored sources.
run_scriptgen "$SCRIPTS"

# 3. Build the scripts dll. The *.gen.odin live in the same package and compile
#    together. ODIN_GD_ATTRS (common.sh) lets authors mark methods with
#    `@(gd_method)` etc. (the codegen markers for GDScript-callable procs).
#    `SCRIPT_BUILD_FLAGS` (env, optional) forwards extra odin flags to the scripts
#    dll build ONLY — e.g. `-define:RELOAD_V=2` to build a v2 for the Phase 4 reload
#    test without rebuilding the core. `SKIP_CORE=1` skips step 4 (a reload rebuild
#    only needs a fresh scripts dll).
# atomic_odin_dll (common.sh) builds to a TEMP output and atomically `mv`s it into place,
# so the live scripts dll is NEVER missing/half-written even if the editor's
# reload-on-save coordinator (core/reload.odin) is interrupted mid-build — the macOS
# packaging fix that ended "failed to load scripts dll" / "No loader found" after an
# interrupted rebuild. It also guarantees a clean build (no stale `.o` against an old
# runtime layout). (Mirrored in build_scripts.ps1.)
SCR_DLL="$BIN/libodinscripts.$DLL_EXT"
CORE_DLL="$BIN/libodin_godot.$DLL_EXT"
atomic_odin_dll "$SCRIPTS" "$SCR_DLL" \
    ${ODIN_GD_ATTRS[@]+"${ODIN_GD_ATTRS[@]}"} \
    -debug ${SCRIPT_BUILD_FLAGS:-}

if [[ "${SKIP_CORE:-0}" == "1" ]]; then
    echo "Built (scripts only):"
    echo "  $SCR_DLL"
    exit 0
fi

# 4. Build the core ScriptLanguageExtension dll (same atomic temp+mv publish as the scripts
#    dll above, so a failed/interrupted core build never deletes the live core dll either).
atomic_odin_dll "$ROOT/core" "$CORE_DLL" -debug

echo "Built:"
echo "  $CORE_DLL"
echo "  $SCR_DLL"

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
# Remove prior outputs + intermediates first: a stale dll / `.o` built against an OLD
# runtime layout can survive an incremental `-out:` build and crash at extension init (the
# same bug class fixed in core/build.sh). A clean output guarantees the dll matches sources.
# This matters most for the editor reload-on-save loop, which rebuilds repeatedly in place.
rm -f "$BIN/libodinscripts.dylib" "$BIN"/libodinscripts-*.o
"$ODIN" build "$SCRIPTS" \
    -collection:godot="$ROOT" \
    -build-mode:dll \
    -custom-attribute:gd_method -custom-attribute:gd_connect -custom-attribute:gd_rpc \
    -out:"$BIN/libodinscripts.dylib" \
    -debug ${SCRIPT_BUILD_FLAGS:-}

if [[ "${SKIP_CORE:-0}" == "1" ]]; then
    echo "Built (scripts only):"
    echo "  $BIN/libodinscripts.dylib"
    exit 0
fi

# 4. Build the core ScriptLanguageExtension dll.
rm -f "$BIN/libodin_godot.dylib" "$BIN"/libodin_godot-*.o
"$ODIN" build "$ROOT/core" \
    -collection:godot="$ROOT" \
    -build-mode:dll \
    -out:"$BIN/libodin_godot.dylib" \
    -debug

echo "Built:"
echo "  $BIN/libodin_godot.dylib"
echo "  $BIN/libodinscripts.dylib"

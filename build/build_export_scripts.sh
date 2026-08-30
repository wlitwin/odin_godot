#!/usr/bin/env bash
# Phase 5 — compile a project's `.odin` scripts into the scripts dll(s) FOR EXPORT.
#
# Invoked by core/export_plugin.odin (OdinExportPlugin._export_begin) via libc.system
# during a Godot export. Same scriptgen + `odin build` pipeline as build_scripts.sh,
# but parametrized on the project, the target platform, and an explicit output path
# (the export plugin then add_shared_object's each file beside the executable).
#
# MODULES: after the MAIN scripts dll (<PROJ>/scripts -> OUT_DLL), each script module
# <PROJ>/modules/<name> is built into <dir of OUT_DLL>/libodinscripts_<name>.<same ext>
# — the exact sibling layout the exported core's load_extra_modules scans for.
# BUILD_MODULES=0 (env) opts out, mirroring build_scripts.sh; the export plugin honors
# the same variable, so the two ends stay consistent.
#
# Usage: build_export_scripts.sh <PROJECT_DIR> <TARGET> <OUT_DLL>
#   TARGET ∈ { macos, linux, windows }   (web uses build_export_wasm.sh)
#
# Cross-compile note: linux/windows targets pass `-target:<os>_amd64`. Odin can emit
# the object, but producing a final .so/.dll requires the matching cross LINKER on
# PATH (lld is in the dev shell; a full sysroot may still be needed). Verified here:
# macos (native). linux/windows: supported-but-unverified — see docs/exporting.md and
# docs/design/export-internals.md.
set -euo pipefail

# Root derived from this script's location (build/ -> root), overridable. Never hardcode a
# checkout path — this ships inside the addon.
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# Shared helpers (ODIN — overridable so the editor's export plugin can pass an absolute
# compiler path — ODIN_GD_ATTRS, build_scriptgen/run_scriptgen, atomic_odin_dll).
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
PROJ="$1"
TARGET="$2"
OUT="$3"
SCRIPTS="$PROJ/scripts"
# Module dlls publish beside the main one (same dir, same target extension) — the
# exported core discovers modules as libodinscripts_<name>.<ext> SIBLINGS of the main
# scripts dll, so building them as siblings here means add_shared_object preserves
# that layout in the bundle.
OUTDIR="$(dirname "$OUT")"
TARGET_EXT="${OUT##*.}"

# Optimization level for the EXPORTED scripts dlls. Unlike the dev rebuild-on-save loop
# (which stays at -o:none for fast iteration), a shipped game wants real optimization.
# Default to `speed`; override per project via the `odin_godot/export_optimization`
# setting (the export plugin forwards it as ODIN_EXPORT_OPT) — one of
# none|minimal|size|speed|aggressive.
OPT="${ODIN_EXPORT_OPT:-speed}"

mkdir -p "$OUTDIR"

# Target -> odin flags. Validated up front, before any build work.
EXTRA=()
case "$TARGET" in
    macos)   ;;                                   # native host arch
    linux)   EXTRA+=(-target:linux_amd64) ;;
    windows) EXTRA+=(-target:windows_amd64) ;;
    *) echo "build_export_scripts.sh: unsupported target '$TARGET'" >&2; exit 2 ;;
esac

# HARD RULE: no imports between script modules — enforced by check_module_isolation,
# which lives in build/common.sh (one canonical implementation, shared with the dev-loop
# build_scripts.sh, so the export build enforces exactly the rule the editor build does).

# 1. Build the scriptgen preprocessor to a writable TEMP dir (never into the addon, which may
#    be read-only when installed under res://addons/). SGEN_BIN env reuses a prebuilt one.
build_scriptgen

# scriptgen + odin build one scripts dir into its export dll, OPTIMIZED. `SCRIPT_BUILD_FLAGS`
# (env) appends extra odin flags for the truly release-minded (e.g. `-no-bounds-check
# -disable-assert`). atomic_odin_dll (common.sh) builds to a temp and publishes with
# `mv -f`, so a failed/aborted export never leaves the output missing/half-written for
# the packer.
build_one_export_dir() {
    local dir="$1" out="$2"
    check_module_isolation "$dir"
    run_scriptgen "$dir" "$PROJ"
    atomic_odin_dll "$dir" "$out" \
        -o:"$OPT" \
        ${ODIN_GD_ATTRS[@]+"${ODIN_GD_ATTRS[@]}"} \
        ${EXTRA[@]+"${EXTRA[@]}"} ${SCRIPT_BUILD_FLAGS:-}
    echo "build_export_scripts.sh: built $out" >&2
}

# 2. The MAIN scripts dll.
build_one_export_dir "$SCRIPTS" "$OUT"

# 3. Each script module (res://modules/<name>) into its sibling dll. BUILD_MODULES=0
#    opts out (same switch as build_scripts.sh). Sourceless module dirs are skipped
#    exactly as the dev build skips them.
if [[ "${BUILD_MODULES:-1}" != "0" && -d "$PROJ/modules" ]]; then
    for mdir in "$PROJ/modules"/*/; do
        mdir="${mdir%/}"
        [ -d "$mdir" ] || continue
        if [ -z "$(ls "$mdir"/*.odin 2>/dev/null)" ]; then
            # Shared phrasing with build_scripts.sh / build_scripts.ps1 — docs/modules.md
            # quotes this exact string.
            echo "build_scripts: skipping module '$(basename "$mdir")' (no .odin sources)" >&2
            continue
        fi
        build_one_export_dir "$mdir" "$OUTDIR/libodinscripts_$(basename "$mdir").$TARGET_EXT"
    done
fi

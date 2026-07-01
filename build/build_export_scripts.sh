#!/usr/bin/env bash
# Phase 5 — compile a project's `.odin` scripts into the scripts dll FOR EXPORT.
#
# Invoked by core/export_plugin.odin (OdinExportPlugin._export_begin) via libc.system
# during a Godot export. Same scriptgen + `odin build` pipeline as build_scripts.sh,
# but parametrized on the project, the target platform, and an explicit output path
# (the export plugin then add_shared_object's that file beside the executable).
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

# Optimization level for the EXPORTED scripts dll. Unlike the dev rebuild-on-save loop (which
# stays at -o:none for fast iteration), a shipped game wants real optimization. Default to
# `speed`; override per project via the `odin_godot/export_optimization` setting (the export
# plugin forwards it as ODIN_EXPORT_OPT) — one of none|minimal|size|speed|aggressive.
OPT="${ODIN_EXPORT_OPT:-speed}"

mkdir -p "$(dirname "$OUT")"

# 1. Build the scriptgen preprocessor to a writable TEMP dir (never into the addon, which may
#    be read-only when installed under res://addons/). SGEN_BIN env reuses a prebuilt one.
build_scriptgen

# 2. Generate *.gen.odin siblings beside the authored sources.
run_scriptgen "$SCRIPTS"

# 3. Target -> odin flags.
EXTRA=()
case "$TARGET" in
    macos)   ;;                                   # native host arch
    linux)   EXTRA+=(-target:linux_amd64) ;;
    windows) EXTRA+=(-target:windows_amd64) ;;
    *) echo "build_export_scripts.sh: unsupported target '$TARGET'" >&2; exit 2 ;;
esac

# 4. Build the scripts dll for the target, OPTIMIZED. `SCRIPT_BUILD_FLAGS` (env) appends extra
#    odin flags for the truly release-minded (e.g. `-no-bounds-check -disable-assert`).
#    atomic_odin_dll (common.sh) builds to a temp and publishes with `mv -f`, so a
#    failed/aborted export never leaves $OUT missing/half-written for the packer.
atomic_odin_dll "$SCRIPTS" "$OUT" \
    -o:"$OPT" \
    ${ODIN_GD_ATTRS[@]+"${ODIN_GD_ATTRS[@]}"} \
    ${EXTRA[@]+"${EXTRA[@]}"} ${SCRIPT_BUILD_FLAGS:-}

echo "build_export_scripts.sh: built $OUT" >&2

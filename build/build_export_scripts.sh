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
# macos (native). linux/windows: supported-but-unverified — see docs/phase5-export.md.
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-/Users/walter/data/code/odin/odin_godot}"
PROJ="$1"
TARGET="$2"
OUT="$3"
SCRIPTS="$PROJ/scripts"

mkdir -p "$(dirname "$OUT")"

# 1. Build the scriptgen preprocessor (cheap; keeps the pipeline self-contained).
odin build "$ROOT/scriptgen" \
    -collection:godot="$ROOT" \
    -out:"$ROOT/scriptgen/scriptgen"

# 2. Generate *.gen.odin siblings beside the authored sources.
"$ROOT/scriptgen/scriptgen" "$SCRIPTS"

# 3. Target -> odin flags.
EXTRA=()
case "$TARGET" in
    macos)   ;;                                   # native host arch
    linux)   EXTRA+=(-target:linux_amd64) ;;
    windows) EXTRA+=(-target:windows_amd64) ;;
    *) echo "build_export_scripts.sh: unsupported target '$TARGET'" >&2; exit 2 ;;
esac

# 4. Build the scripts dll for the target.
odin build "$SCRIPTS" \
    -collection:godot="$ROOT" \
    -build-mode:dll \
    -custom-attribute:gd_method -custom-attribute:gd_connect -custom-attribute:gd_rpc \
    -out:"$OUT" \
    "${EXTRA[@]}"

echo "build_export_scripts.sh: built $OUT" >&2

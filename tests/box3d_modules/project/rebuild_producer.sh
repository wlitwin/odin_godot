#!/usr/bin/env bash
set -euo pipefail
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${ODIN_GODOT_ROOT:?ODIN_GODOT_ROOT must name the tested SDK}"
SKIP_CORE=1 BUILD_MODULES=0 SCRIPT_BUILD_FLAGS=-define:BOX3D_RELOAD_BRAND=2 \
    bash "$ROOT/build/build_scripts.sh" "$PROJ" "$PROJ/scripts"

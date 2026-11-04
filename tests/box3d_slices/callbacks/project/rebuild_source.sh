#!/usr/bin/env bash
set -euo pipefail
project="$(cd "$(dirname "$0")" && pwd)"
SKIP_CORE=1 SCRIPT_BUILD_FLAGS="${SCRIPT_BUILD_FLAGS:-} -define:BOX3D_RELOAD_BRAND=2" BUILD_MODULES=0 bash "$ODIN_GODOT_ROOT/build/build_scripts.sh" "$project" "$project/scripts"

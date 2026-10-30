#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_hello"
scene="${1:-hello}"
case "$scene" in hello|loot|network) ;; *) echo "usage: play.sh [hello|loot|network]" >&2; exit 2 ;; esac
bash "$ROOT/build/build_scripts.sh" "$PROJ"
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
exec "$GODOT" --path "$PROJ" "res://$scene.tscn"

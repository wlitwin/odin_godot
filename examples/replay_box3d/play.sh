#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJ="$ROOT/examples/replay_box3d"
bash "$ROOT/build/build_scripts.sh" "$PROJ"
case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) ext=dll;;esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
exec "$GODOT" --path "$PROJ" "$@"

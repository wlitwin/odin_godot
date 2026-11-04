#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJ="$ROOT/examples/kit_box3d"
MODE="${1:-build}"
if [[ "$MODE" == build ]]; then
    : "${BOX3D_NATIVE_LIBRARY:?Set BOX3D_NATIVE_LIBRARY to the verified shared libogb3.dylib/.so, not a static archive}"
    bash "$ROOT/build/build_scripts.sh" "$PROJ"
    exit 0
fi
case "$MODE" in
    host|client|observer|server|dedicated) export B3_ROLE="$MODE" ;;
    live-host) export B3_ROLE=host B3_SCRIPTED=0 B3_TICKS=0 ;;
    live-client) export B3_ROLE=client B3_SCRIPTED=0 B3_TICKS=0 ;;
    *) echo "usage: $0 build|host|client|observer|server|dedicated|live-host|live-client" >&2; exit 2 ;;
esac
: "${GODOT:=godot}"
exec "$GODOT" --max-fps 60 --path "$PROJ" "${@:2}"

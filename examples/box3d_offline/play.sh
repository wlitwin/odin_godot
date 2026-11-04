#!/usr/bin/env bash
# Build and run the offline Box3D example (no Kit, no Replay). See README.md.
#
#   nix develop --command bash examples/box3d_offline/play.sh [godot args...]
#   nix develop --command bash examples/box3d_offline/play.sh -e   # open the editor
#
# Uses BOX3D_NATIVE_LIBRARY when set; otherwise builds the native library into the
# repository's ignored .box3d-cache (about 15 s the first time, seconds after that).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJ="$ROOT/examples/box3d_offline"
case "$(uname -s)" in
    Darwin) ext=dylib ;;
    Linux) ext=so ;;
    *) ext=dll ;;
esac

if [[ -z "${BOX3D_NATIVE_LIBRARY:-}" ]]; then
    bash "$ROOT/build/build_box3d.sh" Release "$ROOT/.box3d-cache"
    export BOX3D_NATIVE_LIBRARY="$ROOT/.box3d-cache/build/Release/libogb3.$ext"
fi

bash "$ROOT/build/build_scripts.sh" "$PROJ"
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
exec "$GODOT" --path "$PROJ" "$@"

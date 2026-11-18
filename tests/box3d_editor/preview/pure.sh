#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
"${ODIN:-odin}" test "$ROOT/tests/box3d_editor/preview/pure" -collection:godot="$ROOT"
echo BOX3D_PREVIEW_PURE_OK

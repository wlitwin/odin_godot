#!/usr/bin/env bash
# Entity-census correctness in both guard modes. The dev compile covers the
# normal singular result; the release compile proves disabled assertions never
# turn an ambiguity back into "first match wins".
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

"${ODIN:-odin}" test "$ROOT/tests/kitboot" -collection:godot="$ROOT"
"${ODIN:-odin}" test "$ROOT/tests/kitboot" -collection:godot="$ROOT" -disable-assert
echo "KITBOOT_OK"

#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
"${ODIN:-odin}" test "$ROOT/tests/replay_recovery" -collection:godot="$ROOT" -out:"$work/recovery_tests"
# SDK scripts always enable strict domain admission. Value-only backup/restore
# must still run without importing or linking the optional native engine.
"${ODIN:-odin}" test "$ROOT/tests/replay_recovery" -collection:godot="$ROOT" \
    -define:BOX3D_REQUIRE_DOMAIN=true "-define:BOX3D_LIBRARY=$work/missing-libogb3.a" \
    -out:"$work/recovery_strict_tests"
"${ODIN:-odin}" check "$ROOT/tests/replay_recovery/wasm" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point
echo REPLAY_RECOVERY_OK

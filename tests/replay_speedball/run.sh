#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
"${ODIN:-odin}" test "$ROOT/tests/replay_speedball" -collection:godot="$ROOT" -out:"$work/pitch"
"${ODIN:-odin}" check "$ROOT/tests/replay_speedball/wasm" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point
echo REPLAY_SPEEDBALL_CORE_OK

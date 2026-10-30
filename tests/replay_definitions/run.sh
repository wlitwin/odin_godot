#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="$(mktemp -d)";trap 'rm -rf "$work"' EXIT
odin test "$ROOT/tests/replay_definitions" -collection:godot="$ROOT" -out:"$work/definitions"
odin check "$ROOT/tests/replay_definitions/wasm" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point
echo REPLAY_DEFINITIONS_OK

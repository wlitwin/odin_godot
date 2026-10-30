#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="${REPLAY_CAVE_IMPACT_MODEL_OUT:-$(mktemp -d)}";mkdir -p "$work"
odin test "$ROOT/tests/replay_cave_impact" -collection:godot="$ROOT" -out:"$work/impact-tests"
odin check "$ROOT/tests/replay_cave_impact/wasm" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point
echo REPLAY_CAVE_IMPACT_MODEL_OK

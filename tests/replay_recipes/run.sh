#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
odin check "$ROOT/examples/replay_recipes" -collection:godot="$ROOT" -no-entry-point
odin check "$ROOT/examples/replay_recipes" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point
echo REPLAY_RECIPES_OK

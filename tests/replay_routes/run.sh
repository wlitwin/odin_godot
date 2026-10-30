#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="${REPLAY_ROUTES_OUT:-$(mktemp -d)}";mkdir -p "$work"
odin run "$ROOT/tests/replay_routes/native" -collection:godot="$ROOT" -out:"$work/native"
odin build "$ROOT/tests/replay_routes/wasm" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point -out:"$work/routes.wasm"
node "$ROOT/tests/replay_routes/verify.mjs" "$work/routes.wasm"
echo REPLAY_ROUTES_OK

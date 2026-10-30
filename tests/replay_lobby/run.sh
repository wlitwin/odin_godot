#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="$(mktemp -d)";trap 'rm -rf "$work"' EXIT
odin test "$ROOT/tests/replay_lobby" -collection:godot="$ROOT" -out:"$work/lobby"
odin check "$ROOT/replay/lobby" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point
echo REPLAY_LOBBY_OK

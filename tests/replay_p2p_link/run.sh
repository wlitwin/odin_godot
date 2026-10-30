#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="$(mktemp -d)";trap 'rm -rf "$work"' EXIT
odin test "$ROOT/tests/replay_p2p_link" -collection:godot="$ROOT" -out:"$work/test"
odin check "$ROOT/replay/p2p/link" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point
echo REPLAY_P2P_LINK_OK

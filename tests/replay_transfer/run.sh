#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
"${ODIN:-odin}" test "$ROOT/tests/replay_transfer" -collection:godot="$ROOT" -out:"$work/tests"
"${ODIN:-odin}" check "$ROOT/tests/replay_transfer/wasm" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point
bash "$ROOT/tests/replay_transfer/layout_corpus/run.sh"
echo REPLAY_TRANSFER_OK

#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="${REPLAY_INTEREST_CORPUS_OUT:-$(mktemp -d)}";mkdir -p "$work"
trap 'echo "Interest corpus: $work"' EXIT
odin build "$ROOT/tests/replay_interest/native" -collection:godot="$ROOT" -out:"$work/native"
"$work/native" >"$work/native.txt"
odin build "$ROOT/tests/replay_interest/wasm" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point -out:"$work/interest.wasm"
node "$ROOT/tests/replay_interest/compare.mjs" "$work/interest.wasm" "$work/native.txt"
echo REPLAY_INTEREST_CORPUS_OK

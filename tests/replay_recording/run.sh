#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="${REPLAY_RECORDING_OUT:-$(mktemp -d)}";mkdir -p "$work"
trap 'echo "Recording logs: $work"' EXIT
node "$ROOT/tests/replay_recording/file_import_test.mjs"
odin test "$ROOT/tests/replay_diagnostics" -collection:godot="$ROOT" -out:"$work/tests"
odin check "$ROOT/tests/replay_diagnostics/wasm" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point
odin build "$ROOT/examples/replay_hello/tools/verify_recording" -collection:godot="$ROOT" -out:"$work/verify_recording"
odin build "$ROOT/tests/replay_recording/fixture" -collection:godot="$ROOT" -out:"$work/fixture"
"$work/fixture" "$work/wrapped.rplrec"
odin build "$ROOT/tests/replay_recording/wasm" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point -out:"$work/verify.wasm"
node "$ROOT/tests/replay_recording/targets.mjs" "$work/verify.wasm" "$work/verify_recording" "$work/wrapped.rplrec" "$work/wrapped.rplrec.empty.rplrec" "$@" | tee "$work/targets.log"
echo REPLAY_RECORDING_OK

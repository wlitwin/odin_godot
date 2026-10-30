#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="${REPLAY_TRANSPORT_TRACE_OUT:-$(mktemp -d)}";mkdir -p "$work"
odin test "$ROOT/tests/replay_transport_trace" -collection:godot="$ROOT" -out:"$work/trace-tests"
odin check "$ROOT/tests/replay_transport_trace/wasm" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point
echo REPLAY_TRANSPORT_TRACE_OK

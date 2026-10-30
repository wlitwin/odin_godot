#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
odin test "$ROOT/tests/replay_telemetry" -collection:godot="$ROOT" -out:"$work/telemetry"
odin check "$ROOT/replay/telemetry" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point
echo REPLAY_TELEMETRY_OK

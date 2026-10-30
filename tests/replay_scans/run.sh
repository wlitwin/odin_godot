#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="${REPLAY_SCANS_OUT:-$(mktemp -d)}";mkdir -p "$work"
trap 'echo "Scan benchmark logs: $work"' EXIT
odin build "$ROOT/tests/replay_scans" -collection:godot="$ROOT" -o:speed -out:"$work/scans"
"$work/scans" >"$work/native.log"
python3 "$ROOT/tests/replay_scans/report.py" "$work"
odin build "$ROOT/tests/replay_scans/wasm" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point -o:speed -out:"$work/scans.wasm"
node "$ROOT/tests/replay_scans/check.mjs" "$work/scans.wasm" "$work/native.log"
echo REPLAY_SCANS_OK

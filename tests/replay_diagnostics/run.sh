#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="${REPLAY_DIAGNOSTICS_OUT:-$(mktemp -d)}";mkdir -p "$work"
trap 'echo "Diagnostic logs: $work"' EXIT
odin build "$ROOT/examples/replay_scrapyard/tools/inspect_run" -collection:godot="$ROOT" -out:"$work/inspect_run"
odin build "$ROOT/tests/replay_diagnostics/fixtures" -collection:godot="$ROOT" -out:"$work/fixture"
odin build "$ROOT/examples/replay_scrapyard/tools/upgrade_run" -collection:godot="$ROOT" -out:"$work/upgrade_run"
for name in plain spray; do
  "$work/upgrade_run" "$ROOT/tests/replay_diagnostics/fixtures/$name.replay" "$work/$name.replay" --token protocol-upgrade-owner
done
"$work/fixture" "$work/plain.replay" "$work/changed.replay"
python3 "$ROOT/tests/replay_diagnostics/verify.py" "$work"
odin check "$ROOT/tests/replay_diagnostics/wasm" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point

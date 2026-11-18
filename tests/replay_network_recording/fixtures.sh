#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="${REPLAY_RECORDING_FIXTURES_OUT:-$(mktemp -d)}";mkdir -p "$work"
python3 "$ROOT/tests/replay_network_recording/fixtures.py" "$work/recordings"
bash "$ROOT/tests/replay_network_recording/targets.sh" "$work/targets" "$work/recordings/0.rplrec" "$work/recordings/1.rplrec" "$work/recordings/2.rplrec"
echo REPLAY_RECORDING_CURRENT_FIXTURES_OK

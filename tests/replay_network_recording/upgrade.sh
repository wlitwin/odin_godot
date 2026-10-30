#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="${REPLAY_RECORDING_UPGRADE_OUT:-$(mktemp -d)}";mkdir -p "$work"
odin build "$ROOT/examples/replay_scrapyard/tools/upgrade_recording" -collection:godot="$ROOT" -out:"$work/upgrade_recording"
odin build "$ROOT/examples/replay_scrapyard/tools/verify_recording" -collection:godot="$ROOT" -out:"$work/verify_recording"
python3 "$ROOT/tests/replay_network_recording/upgrade.py" "$work"
REPLAY_RECORDING_CONTENT48=1 bash "$ROOT/tests/replay_network_recording/targets.sh" "$work/targets" "$work/upgraded/0.rplrec" "$work/upgraded/1.rplrec" "$work/upgraded/2.rplrec"
echo REPLAY_RECORDING_AUTHORITY_UPGRADE_OK

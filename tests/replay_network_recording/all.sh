#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_NETWORK_RECORDING_OUT:-$(mktemp -d)}";mkdir -p "$work"
REPLAY_NETWORK_RECORDING_OUT="$work/native" bash "$ROOT/tests/replay_network_recording/run.sh"
bash "$ROOT/tests/replay_network_recording/web.sh" "$work/native" "$work/web"
bash "$ROOT/tests/replay_network_recording/targets.sh" "$work/targets" "$work/native/run/host.rplrec" "$work/native/run/client.rplrec" "$work/web/browser/downloads/scrapyard.rplrec"
echo REPLAY_NETWORK_RECORDING_ALL_OK

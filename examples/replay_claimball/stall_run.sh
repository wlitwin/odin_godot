#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
RCB_STALL_MS=800 bash "$ROOT/examples/replay_claimball/network_run.sh"
echo REPLAY_CLAIMBALL_STALL_OK

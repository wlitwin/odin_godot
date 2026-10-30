#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
RCB_REQUIRE_FAULTS=1 RCB_JITTER=20 RCB_LOSS=1000 RCB_DUPLICATE=1000 \
  bash "$ROOT/examples/replay_claimball/compete_run.sh"
echo REPLAY_CLAIMBALL_FAULT_OK

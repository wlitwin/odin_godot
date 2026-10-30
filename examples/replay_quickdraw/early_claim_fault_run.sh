#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
RQ_JITTER=20 RQ_LOSS=1000 RQ_DUPLICATE=1000 bash "$ROOT/examples/replay_quickdraw/early_claim_run.sh"
echo REPLAY_QUICKDRAW_EARLY_CLAIM_FAULT_OK

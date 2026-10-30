#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
RQ_EARLY_CLAIM=1 RQ_CRASH_AFTER=600 REPLAY_MIGRATION_PHASE=crash \
  bash "$ROOT/examples/replay_quickdraw/migration_run.sh"
echo REPLAY_QUICKDRAW_EARLY_CLAIM_OK

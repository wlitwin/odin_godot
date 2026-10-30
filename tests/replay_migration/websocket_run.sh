#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export REPLAY_CONTROL_WS=1
REPLAY_MIGRATION_MODE=planned bash "$ROOT/tests/replay_migration/run.sh"
REPLAY_PREBUILT=1 REPLAY_MIGRATION_MODE=crash bash "$ROOT/tests/replay_migration/run.sh"
echo REPLAY_MIGRATION_WEBSOCKET_OK

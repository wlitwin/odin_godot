#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_BACKUP_STATUS_OUT:-$(mktemp -d)}";mkdir -p "$work"
bash "$ROOT/tests/replay_room_backup_status/build.sh" "$work/app"
bash "$ROOT/tests/replay_slopball_online/build_service.sh" "$work/service"
python3 "$ROOT/tests/replay_room_backup_status/execute.py" "$work/app" "$work/service" "$work/run"

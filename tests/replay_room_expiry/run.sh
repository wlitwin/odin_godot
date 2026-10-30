#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_ROOM_EXPIRY_OUT:-$(mktemp -d)}";mkdir -p "$work"
python3 "$ROOT/tests/replay_room_expiry/prepare.py" "$work/app"
bash "$ROOT/build/build_scripts.sh" "$work/app/project" >"$work/app/build.log" 2>&1
bash "$ROOT/tests/replay_claimball_ui/build.sh" "$work/app"
python3 "$ROOT/tests/replay_claimball_migration/prepare_coordinator.py" "$work/coordinator"
bash "$ROOT/build/build_scripts.sh" "$work/coordinator/project" >"$work/coordinator/build.log" 2>&1
bash "$ROOT/tests/replay_claimball_ui/build.sh" "$work/coordinator"
python3 "$ROOT/tests/replay_room_expiry/execute.py" "$work/app" "$work/coordinator" "$work/run"

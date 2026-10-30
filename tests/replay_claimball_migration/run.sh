#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_CLAIMBALL_MIGRATION_OUT:-$(mktemp -d)}";mkdir -p "$work"
REPLAY_CLAIMBALL_UI_OUT="$work/app" bash "$ROOT/tests/replay_claimball_ui/run.sh"
python3 "$ROOT/tests/replay_claimball_migration/prepare_coordinator.py" "$work/coordinator"
bash "$ROOT/build/build_scripts.sh" "$work/coordinator/project" >"$work/coordinator/build.log" 2>&1
bash "$ROOT/tests/replay_claimball_ui/build.sh" "$work/coordinator"
python3 "$ROOT/tests/replay_claimball_migration/execute.py" "$work/app" "$work/coordinator" "$work/run"

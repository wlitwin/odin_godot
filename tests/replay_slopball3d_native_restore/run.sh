#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_SLOPBALL3D_NATIVE_RESTORE_OUT:-$(mktemp -d)}";mkdir -p "$work"
REPLAY_SLOPBALL3D_UI_OUT="$work/game" bash "$ROOT/tests/replay_slopball3d_ui/run.sh"
bash "$ROOT/tests/replay_slopball3d_online/build_service.sh" "$work/service"
for restoring_role in host striker; do
 RS3_RESTORE_OWNER="$restoring_role" python3 "$ROOT/tests/replay_slopball3d_native_restore/execute.py" "$work/game" "$work/service" "$work/restore-$restoring_role"
 odin run "$ROOT/tests/replay_slopball3d_party_restore/verify" -collection:godot="$ROOT" -- "$work/restore-$restoring_role/service.sqlite3" continued "$restoring_role" >"$work/durable-$restoring_role.log" 2>&1
done
echo REPLAY_SLOPBALL3D_NATIVE_RESTORE_OK

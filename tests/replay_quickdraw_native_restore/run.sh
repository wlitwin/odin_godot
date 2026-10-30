#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_QUICKDRAW_NATIVE_RESTORE_OUT:-$(mktemp -d)}";mkdir -p "$work"
REPLAY_QUICKDRAW_UI_OUT="$work/game" bash "$ROOT/tests/replay_quickdraw_ui/run.sh"
bash "$ROOT/tests/replay_quickdraw_online/build_service.sh" "$work/service"
python3 "$ROOT/tests/replay_quickdraw_native_restore/execute.py" "$work/game" "$work/service" "$work/restore"
odin run "$ROOT/tests/replay_quickdraw_online/verify" -collection:godot="$ROOT" -- "$work/restore/service.sqlite3" >"$work/durable.log" 2>&1
echo REPLAY_QUICKDRAW_NATIVE_RESTORE_OK

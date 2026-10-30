#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_SLOPBALL_ONLINE_OUT:-$(mktemp -d)}";mkdir -p "$work"
REPLAY_SLOPBALL_UI_OUT="$work/native-game" bash "$ROOT/tests/replay_slopball_ui/run.sh"
bash "$ROOT/tests/replay_slopball_online/build_service.sh" "$work/service"
bash "$ROOT/tests/replay_slopball_online/build_web.sh" "$work/native-game" "$work/web"
bash "$ROOT/tests/replay_slopball_online/execute_web.sh" "$work/web" "$work/service" "$work/browser-run"
odin run "$ROOT/tests/replay_slopball_online/verify" -collection:godot="$ROOT" -- "$work/browser-run/service.sqlite3" >"$work/publications.log" 2>&1
python3 "$ROOT/tests/replay_slopball_online/native.py" "$work/native-game" "$work/service" "$work/native-party"
echo REPLAY_SLOPBALL_ONLINE_OK

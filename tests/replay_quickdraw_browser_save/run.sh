#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_QUICKDRAW_BROWSER_SAVE_OUT:-$(mktemp -d)}";mkdir -p "$work"
REPLAY_QUICKDRAW_UI_OUT="$work/native" bash "$ROOT/tests/replay_quickdraw_ui/run.sh"
bash "$ROOT/tests/replay_quickdraw_online/build_web.sh" "$work/native" "$work/web"
bash "$ROOT/tests/replay_quickdraw_browser_save/execute.sh" "$work/web" "$work/run"
echo REPLAY_QUICKDRAW_BROWSER_SAVE_OK

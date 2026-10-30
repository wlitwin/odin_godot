#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_SLOPBALL_BROWSER_SAVE_OUT:-$(mktemp -d)}";mkdir -p "$work"
REPLAY_SLOPBALL_UI_OUT="$work/native" bash "$ROOT/tests/replay_slopball_ui/run.sh"
bash "$ROOT/tests/replay_slopball_online/build_web.sh" "$work/native" "$work/web"
bash "$ROOT/tests/replay_slopball_browser_save/execute.sh" "$work/web" "$work/run"
echo REPLAY_SLOPBALL_BROWSER_SAVE_OK

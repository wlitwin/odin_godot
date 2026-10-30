#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_QUICKDRAW_FEEDBACK_OUT:-$(mktemp -d)}";mkdir -p "$work"
REPLAY_QUICKDRAW_UI_OUT="$work" bash "$ROOT/tests/replay_quickdraw_ui/run.sh"
python3 "$ROOT/tests/replay_quickdraw_feedback/execute.py" "$work"
echo REPLAY_QUICKDRAW_FEEDBACK_OK

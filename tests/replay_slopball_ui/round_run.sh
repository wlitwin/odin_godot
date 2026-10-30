#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_SLOPBALL_ROUND_OUT:-$(mktemp -d)}";mkdir -p "$work"
REPLAY_SLOPBALL_UI_OUT="$work" bash "$ROOT/tests/replay_slopball_ui/run.sh"
python3 "$ROOT/tests/replay_slopball_ui/execute.py" "$work" rounds rounds

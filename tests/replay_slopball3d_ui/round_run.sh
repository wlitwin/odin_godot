#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_SLOPBALL3D_ROUND_OUT:-$(mktemp -d)}";mkdir -p "$work"
REPLAY_SLOPBALL3D_UI_OUT="$work" bash "$ROOT/tests/replay_slopball3d_ui/run.sh"
python3 "$ROOT/tests/replay_slopball3d_ui/execute.py" "$work" rounds rounds

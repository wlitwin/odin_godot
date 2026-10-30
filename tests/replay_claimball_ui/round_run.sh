#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_CLAIMBALL_ROUND_OUT:-$(mktemp -d)}";mkdir -p "$work"
REPLAY_CLAIMBALL_UI_OUT="$work" bash "$ROOT/tests/replay_claimball_ui/run.sh"
python3 "$ROOT/tests/replay_claimball_ui/execute.py" "$work" rounds rounds
python3 "$ROOT/tests/replay_claimball_ui/execute.py" "$work" dedicated rounds-dedicated

#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
export REPLAY_EDITOR_OUT="${REPLAY_EDITOR_OUT:-$(mktemp -d)}";mkdir -p "$REPLAY_EDITOR_OUT"
odin test "$ROOT/tests/replay_editor/model" -collection:godot="$ROOT" -out:"$REPLAY_EDITOR_OUT/models"
bash "$ROOT/tests/replay_recipes/run.sh"
bash "$ROOT/tests/replay_editor/build.sh"
python3 "$ROOT/tests/replay_editor/execute.py" "$REPLAY_EDITOR_OUT"
python3 "$ROOT/tests/replay_scrapyard_bridge/execute.py" "$REPLAY_EDITOR_OUT"
python3 "$ROOT/tests/replay_editor/network.py" "$REPLAY_EDITOR_OUT"
echo REPLAY_EDITOR_OK

#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
export REPLAY_SCRAP_BRIDGE_OUT="${REPLAY_SCRAP_BRIDGE_OUT:-$(mktemp -d)}"
mkdir -p "$REPLAY_SCRAP_BRIDGE_OUT"
odin test "$ROOT/tests/replay_scrapyard_bridge/model" -collection:godot="$ROOT" -out:"$REPLAY_SCRAP_BRIDGE_OUT/model-tests"
bash "$ROOT/tests/replay_scrapyard_bridge/build.sh"
python3 "$ROOT/tests/replay_scrapyard_bridge/execute.py" "$REPLAY_SCRAP_BRIDGE_OUT"

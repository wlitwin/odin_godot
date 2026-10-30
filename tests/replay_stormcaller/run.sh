#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
export REPLAY_STORM_OUT="${REPLAY_STORM_OUT:-$(mktemp -d)}";mkdir -p "$REPLAY_STORM_OUT"
python3 "$ROOT/examples/replay_scrapyard/tools/stock.py" --check
odin test "$ROOT/tests/replay_stormcaller/model" -collection:godot="$ROOT" -out:"$REPLAY_STORM_OUT/unit"
bash "$ROOT/tests/replay_stormcaller/corpus.sh" "$REPLAY_STORM_OUT/corpus"
bash "$ROOT/tests/replay_stormcaller/build.sh"
python3 "$ROOT/tests/replay_stormcaller/execute.py" "$REPLAY_STORM_OUT"
echo REPLAY_STORMCALLER_OK

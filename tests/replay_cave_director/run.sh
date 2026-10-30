#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_CAVE_DIRECTOR_OUT:-$(mktemp -d)}";mkdir -p "$work"
bash "$ROOT/tests/replay_cave/run.sh"
odin run "$ROOT/tests/replay_cave_director/oracle" -collection:godot="$ROOT" -out:"$work/oracle"
odin build "$ROOT/tests/replay_cave_director/wasm" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point -out:"$work/director.wasm"
node "$ROOT/tests/replay_cave_director/wasm.mjs" "$work/director.wasm"
bash "$ROOT/tests/replay_cave_director/build.sh" "$work/native"
python3 "$ROOT/tests/replay_cave_director/upgrade.py" "$work/native"
python3 "$ROOT/tests/replay_cave_director/campaign.py" "$work/native" normal
python3 "$ROOT/tests/replay_cave_director/campaign.py" "$work/native" fault
echo REPLAY_CAVE_DIRECTOR_OK

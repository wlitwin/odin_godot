#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_CAVE_FLOOR_OUT:-$(mktemp -d)}";mkdir -p "$work"
bash "$ROOT/tests/replay_cave/run.sh"
bash "$ROOT/tests/replay_cave_floor/build.sh" "$work/native"
python3 "$ROOT/tests/replay_cave_director/upgrade.py" "$work/native"
python3 "$ROOT/tests/replay_cave_floor/transitions.py" "$work/native"
python3 "$ROOT/tests/replay_cave_director/campaign.py" "$work/native" normal
python3 "$ROOT/tests/replay_cave_director/campaign.py" "$work/native" fault
echo REPLAY_CAVE_FLOOR_STATE_OK

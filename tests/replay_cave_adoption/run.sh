#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_CAVE_ADOPTION_OUT:-$(mktemp -d)}";mkdir -p "$work"
bash "$ROOT/tests/replay_net/run.sh"
bash "$ROOT/tests/replay_cave/run.sh"
bash "$ROOT/tests/replay_cave_adoption/build.sh" "$work/native"
python3 "$ROOT/tests/replay_cave_director/upgrade.py" "$work/native"
python3 "$ROOT/tests/replay_cave_adoption/migrations.py" "$work/native" adoptions
python3 "$ROOT/tests/replay_cave_carrier/migrations.py" "$work/native" carriers
python3 "$ROOT/tests/replay_cave_director/campaign.py" "$work/native" normal
python3 "$ROOT/tests/replay_cave_director/campaign.py" "$work/native" fault
echo REPLAY_CAVE_ADOPTION_OK

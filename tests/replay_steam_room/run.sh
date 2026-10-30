#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_STEAM_ROOM_OUT:-$(mktemp -d)}";mkdir -p "$work"
bash "$ROOT/tests/replay_steam_core/run.sh"
bash "$ROOT/tests/replay_steam_room/failures.sh" "$work/failures"
bash "$ROOT/tests/replay_steam_room/build.sh" "$work/app"
STEAM_VIRTUAL_PORT=0 CAVE_CARRIER_COORDINATOR="$work/app/coordinator" python3 "$ROOT/tests/replay_cave_carrier/migrations.py" "$work/app"
python3 "$ROOT/tests/replay_steam_room/verify.py" "$work/app"
for mode in repeat return;do python3 "$ROOT/tests/replay_steam_room/extended.py" "$work/app" "$work/$mode" "$mode";done
echo REPLAY_STEAM_ROOM_CONTRACT_ALL_OK

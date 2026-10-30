#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_DEDICATED_ROOM_OUT:-$(mktemp -d)}";mkdir -p "$work"
bash "$ROOT/tests/replay_provision_godot_core/run.sh"
bash "$ROOT/tests/replay_dedicated_room/build.sh" "$work/build"
for mode in planned crash repeat;do python3 "$ROOT/tests/replay_dedicated_room/execute.py" "$work/$mode" "$mode";done
echo REPLAY_DEDICATED_ROOM_COMPLETE_OK

#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_RESTORE_RENEWAL_OUT:-$(mktemp -d)}";mkdir -p "$work"
bash "$ROOT/tests/replay_authority/run.sh"
bash "$ROOT/tests/replay_provision_godot_core/run.sh"
bash "$ROOT/tests/replay_provision_sqlite/run.sh"
REPLAY_CHECKPOINT_OUT="$work/checkpoints" CHECKPOINT_RESTORE=1 CHECKPOINT_RESTORE_DELAY_MS=2400 bash "$ROOT/tests/replay_room_checkpoint/run.sh"
for game in cavecrawl speedball scrapyard;do
 rg -q 'ROOM_CHECKPOINT_RESTORE_GRANT epoch=2 live=false remaining=0' "$work/checkpoints/$game/client-1.log"
 rg -q 'ROOM_CHECKPOINT_RESTORE_REFRESH epoch=2' "$work/checkpoints/$game/client-1.log"
done
bash "$ROOT/tests/replay_restore_renewal/build.sh" "$work/live"
python3 "$ROOT/tests/replay_restore_renewal/execute.py" "$work/live"
bash "$ROOT/tests/replay_claimball_online/build_web.sh" "$work/live/game" "$work/live/web"
python3 "$ROOT/tests/replay_restore_renewal/execute_web.py" "$work/live"
echo REPLAY_RESTORE_RENEWAL_OK

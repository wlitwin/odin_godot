#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_CAVE_IMPACT_OUT:-$(mktemp -d)}";mkdir -p "$work/tools"
bash "$ROOT/tests/replay_cave/run.sh"
REPLAY_CAVE_IMPACT_MODEL_OUT="$work/model" bash "$ROOT/tests/replay_cave_impact/model_run.sh"
bash "$ROOT/tests/replay_cave_impact/wasm_run.sh" "$work/wasm"
odin test "$ROOT/tests/replay_cave_owner" -collection:godot="$ROOT" -out:"$work/owner-tests"
odin build "$ROOT/examples/replay_cavecrawl/tools/upgrade_save" -collection:godot="$ROOT" -out:"$work/tools/upgrade-cave"
odin build "$ROOT/examples/replay_cavecrawl_owned/tools/upgrade_save" -collection:godot="$ROOT" -out:"$work/tools/upgrade-owner"
python3 "$ROOT/tests/replay_cave_impact/upgrade.py" "$work/tools" "$work/upgrades"
for profile in server owner;do
 bash "$ROOT/tests/replay_cave_feedback/build.sh" "$work/$profile" "$profile"
 python3 "$ROOT/tests/replay_cave_feedback/execute.py" "$work/$profile" "$work/$profile-campaign" campaign
 kind=cave;if [[ "$profile" == owner ]];then kind=owner;fi
 python3 "$ROOT/tests/replay_cave_impact/resume.py" "$work/$profile" "$work/upgrades" "$work/$profile-resume" "$kind"
done
for mode in generation fault rendered;do python3 "$ROOT/tests/replay_cave_feedback/execute.py" "$work/server" "$work/$mode" "$mode";done
bash "$ROOT/tests/replay_cave_feedback/browser_build.sh" "$work/server"
python3 "$ROOT/tests/replay_cave_feedback/browser_execute.py" "$work/server" "$work/visual-browser"
REPLAY_CAVE_OWNER_WEB_OUT="$work/migration-browser" bash "$ROOT/tests/replay_cave_owner/browser_run.sh"
CHECKPOINT_GAMES='cavecrawl cavecrawl-owned' CHECKPOINT_RESTORE=1 REPLAY_CHECKPOINT_OUT="$work/checkpoints" bash "$ROOT/tests/replay_room_checkpoint/run.sh"
echo REPLAY_CAVE_IMPACT_OK

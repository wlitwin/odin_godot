#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_CAVE_ROCKS_OUT:-$(mktemp -d)}";mkdir -p "$work"
bash "$ROOT/tests/replay_view/run.sh"
odin test "$ROOT/tests/replay_cave_rocks/model" -collection:godot="$ROOT" -out:"$work/model-tests"
for profile in server owner;do
 bash "$ROOT/tests/replay_cave_rocks/build.sh" "$work/$profile" "$profile"
 for fps in 30 60 144;do python3 "$ROOT/tests/replay_cave_rocks/execute.py" "$work/$profile" "$work/$profile-$fps" "$fps";done
 CAVE_FEEDBACK_DRIVER="$ROOT/tests/replay_cave_rocks/visual.gd" python3 "$ROOT/tests/replay_cave_feedback/execute.py" "$work/$profile" "$work/$profile-visual" visual
 python3 "$ROOT/tests/replay_cave_feedback/execute.py" "$work/$profile" "$work/$profile-campaign" campaign
done
python3 "$ROOT/tests/replay_cave_feedback/execute.py" "$work/server" "$work/fault" fault
CAVE_FEEDBACK_DRIVER="$ROOT/tests/replay_cave_rocks/visual.gd" python3 "$ROOT/tests/replay_cave_feedback/execute.py" "$work/server" "$work/rendered" rendered
bash "$ROOT/tests/replay_cave_feedback/browser_build.sh" "$work/server"
python3 "$ROOT/tests/replay_cave_feedback/browser_execute.py" "$work/server" "$work/browser"
echo REPLAY_CAVE_ROCKS_OK

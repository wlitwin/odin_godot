#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_CAVE_FEEDBACK_OUT:-$(mktemp -d)}";mkdir -p "$work"
bash "$ROOT/tests/replay_view/run.sh"
for profile in server owner;do
 bash "$ROOT/tests/replay_cave_feedback/build.sh" "$work/$profile" "$profile"
 for mode in visual colors campaign;do python3 "$ROOT/tests/replay_cave_feedback/execute.py" "$work/$profile" "$work/$profile-$mode" "$mode";done
done
python3 "$ROOT/tests/replay_cave_feedback/execute.py" "$work/server" "$work/fault" fault
python3 "$ROOT/tests/replay_cave_feedback/execute.py" "$work/server" "$work/rendered" rendered
bash "$ROOT/tests/replay_cave_feedback/browser_build.sh" "$work/server"
python3 "$ROOT/tests/replay_cave_feedback/browser_execute.py" "$work/server" "$work/browser"
echo REPLAY_CAVE_FEEDBACK_OK

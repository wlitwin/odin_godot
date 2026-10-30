#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_CAVE_CONTEXT_OUT:-$(mktemp -d)}";mkdir -p "$work"
bash "$ROOT/tests/replay_owned/run.sh"
odin test "$ROOT/tests/replay_cave_owner" -collection:godot="$ROOT" -out:"$work/model-tests"
bash "$ROOT/tests/replay_cave_context/build.sh" "$work/app"
python3 "$ROOT/tests/replay_cave_context/execute.py" "$work/app" "$work/live"
odin build "$ROOT/examples/replay_cavecrawl_owned/tools/upgrade_save" -collection:godot="$ROOT" -out:"$work/upgrade"
python3 "$ROOT/tests/replay_cave_context/upgrade.py" "$work/upgrade" "$work/upgrades"
python3 "$ROOT/tests/replay_cave_context/resume.py" "$work/app" "$work/upgrades" "$work/resume"
echo REPLAY_CAVE_ACTION_CONTEXT_OK

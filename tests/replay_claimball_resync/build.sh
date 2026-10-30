#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="$1"
python3 "$ROOT/tests/replay_claimball_resync/prepare.py" "$work"
bash "$ROOT/build/build_scripts.sh" "$work/project" >"$work/build.log" 2>&1
bash "$ROOT/tests/replay_claimball_ui/build.sh" "$work"
odin build "$ROOT/tests/replay_claimball_trace/replay" -collection:godot="$ROOT" -out:"$work/replay-trace" >"$work/replayer-build.log" 2>&1

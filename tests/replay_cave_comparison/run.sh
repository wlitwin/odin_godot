#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_CAVE_COMPARISON_OUT:-$(mktemp -d)}";mkdir -p "$work"
bash "$ROOT/tests/replay_cave_comparison/build.sh" "$work/prepared"
python3 "$ROOT/tests/replay_cave_comparison/authoring.py" "$work/authoring.json"
python3 "$ROOT/tests/replay_cave_comparison/cohort.py" "$work/prepared" "$work/cohort"
echo REPLAY_CAVE_COMPARISON_OK

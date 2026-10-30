#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export REPLAY_EDITOR_OUT="${REPLAY_TURRET_OUT:?Choose a fresh absolute output directory}"
bash "$ROOT/tests/replay_editor/build.sh"
cp "$ROOT/tests/replay_turret/peers.gd" "$REPLAY_EDITOR_OUT/project/turret_peers.gd"
cp "$ROOT/tests/replay_turret/workbench.gd" "$REPLAY_EDITOR_OUT/project/turret_workbench_test.gd"

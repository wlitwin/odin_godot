#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_BRIDGE_OUT:-$(mktemp -d)}";mkdir -p "$work"
for gate in replay replay_view replay_definitions replay_owned replay_routes replay_recipes;do
 bash "$ROOT/tests/$gate/run.sh" >"$work/$gate.log" 2>&1
 echo "$gate passed"
done
export REPLAY_NODES_OUT="${REPLAY_NODES_OUT:-$work/nodes}"
bash "$ROOT/tests/replay_nodes/run.sh" >"$work/nodes.log" 2>&1
echo "replay_nodes passed"
echo REPLAY_BRIDGE_OK

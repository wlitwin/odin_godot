#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_ADAPTER_OUT:?Choose a fresh absolute output directory}";mkdir -p "$work"
odin build "$ROOT/scriptgen" -collection:godot="$ROOT" -out:"$work/scriptgen"
export SGEN_BIN="$work/scriptgen"
python3 "$ROOT/tests/replay_adapter/codegen.py" "$SGEN_BIN" "$work/codegen"
bash "$ROOT/tests/scriptgen/run.sh"
odin test "$ROOT/tests/replay_adapter/model" -collection:godot="$ROOT" -out:"$work/model"
odin check "$ROOT/tests/replay_adapter/wasm" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point
bash "$ROOT/tests/replay_view/run.sh"
REPLAY_NODES_OUT="$work/nodes" bash "$ROOT/tests/replay_nodes/run.sh"
odin test "$ROOT/tests/replay_editor/model" -collection:godot="$ROOT" -out:"$work/editor-model"
odin test "$ROOT/tests/replay_stormcaller/model" -collection:godot="$ROOT" -out:"$work/storm-model"
bash "$ROOT/tests/replay_stormcaller/corpus.sh" "$work/corpus"
export REPLAY_EDITOR_OUT="$work/editor" REPLAY_ADAPTER_PROBES=1
bash "$ROOT/tests/replay_editor/build.sh"
python3 "$ROOT/tests/replay_editor/execute.py" "$REPLAY_EDITOR_OUT"
python3 "$ROOT/tests/replay_adapter/execute.py" "$REPLAY_EDITOR_OUT"
python3 "$ROOT/tests/replay_authoring/artifact.py" "$REPLAY_EDITOR_OUT/project" "$work/artifacts"
python3 "$ROOT/tests/replay_editor/network.py" "$REPLAY_EDITOR_OUT"
bash "$ROOT/tests/replay_editor/migration_build.sh" "$work/coordinator"
python3 "$ROOT/tests/replay_adapter/migration.py" "$REPLAY_EDITOR_OUT/project" "$work/coordinator/project" "$work/migration"
echo REPLAY_ADAPTER_OK

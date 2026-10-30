#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_WORKFLOW_OUT:?Choose a fresh absolute output directory}";mkdir -p "$work"
export REPLAY_EDITOR_OUT="$work/editor"
bash "$ROOT/tests/replay_editor/build.sh"
python3 "$ROOT/tests/replay_editor_workflow/execute.py" "$REPLAY_EDITOR_OUT"
python3 "$ROOT/tests/replay_editor/execute.py" "$REPLAY_EDITOR_OUT"
python3 "$ROOT/tests/replay_editor_workflow/editor.py" "$REPLAY_EDITOR_OUT/project" "$work/editor-ui"
python3 "$ROOT/tests/replay_editor_workflow/commands.py" "$REPLAY_EDITOR_OUT/project" "$work/commands"
python3 "$ROOT/tests/replay_editor_workflow/tools_test.py" "$work/tool-checks" "$REPLAY_EDITOR_OUT/project" --draft copper_relay
odin test "$ROOT/tests/replay_scrapyard" -collection:godot="$ROOT" -out:"$work/model"
odin test "$ROOT/tests/replay_stormcaller/model" -collection:godot="$ROOT" -out:"$work/storm-model"
bash "$ROOT/tests/replay_stormcaller/corpus.sh" "$work/corpus"
echo REPLAY_EDITOR_WORKFLOW_OK

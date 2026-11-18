#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
python3 "$ROOT/tests/replay_editor_workflow/contracts_test.py"
python3 "$ROOT/tests/replay_editor_workflow/generic_editor.py"
echo REPLAY_AUTHORING_EDITOR_OK

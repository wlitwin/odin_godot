#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_CLAIMBALL_UI_OUT:-$(mktemp -d)}";mkdir -p "$work"
python3 "$ROOT/tests/replay_claimball_ui/prepare.py" "$work"
bash "$ROOT/build/build_scripts.sh" "$work/project" >"$work/build.log" 2>&1
bash "$ROOT/tests/replay_claimball_ui/build.sh" "$work"
python3 "$ROOT/tests/replay_claimball_ui/execute.py" "$work"
python3 "$ROOT/tests/replay_claimball_ui/profile.py" "$work"
odin check "$work/project/scripts" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point -custom-attribute:gd_method >"$work/wasm.log" 2>&1
echo REPLAY_CLAIMBALL_UI_OK

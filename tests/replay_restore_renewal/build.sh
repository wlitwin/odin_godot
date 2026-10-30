#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="$1"
python3 "$ROOT/tests/replay_restore_renewal/prepare.py" "$work/game"
bash "$ROOT/build/build_scripts.sh" "$work/game/project" >"$work/game/build.log" 2>&1
bash "$ROOT/tests/replay_claimball_ui/build.sh" "$work/game"
odin check "$work/game/project/scripts" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point -custom-attribute:gd_method >"$work/game/wasm.log" 2>&1
bash "$ROOT/tests/replay_claimball_online/build_service.sh" "$work/service"

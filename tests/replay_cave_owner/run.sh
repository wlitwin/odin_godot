#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_CAVE_OWNER_OUT:-$(mktemp -d)}";mkdir -p "$work"
odin test "$ROOT/tests/replay_cave_owner" -collection:godot="$ROOT" -out:"$work/model-tests"
odin check "$ROOT/tests/replay_cave_owner/wasm" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point
bash "$ROOT/examples/replay_cavecrawl_owned/build.sh" "$work/app"
case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) exit 1;;esac
ODIN_SCRIPTS_DLL="$work/app/project/bin/libodinscripts.$ext" REPLAY_CAVE_ROLE='' REPLAY_CAVE_PERSIST=0 "$GODOT" --headless --path "$work/app/project" --script "$ROOT/tests/replay_cave_owner/defaults.gd" >"$work/defaults.log" 2>&1
rg -q '^REPLAY_CAVE_OWNER_DEFAULTS_OK' "$work/defaults.log"
odin check "$work/app/project/scripts" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point -define:ODIN_GODOT_WEB=true -custom-attribute:gd_method
for mode in network fault flow;do python3 "$ROOT/tests/replay_cave_owner/execute.py" "$work/app" "$work/$mode" "$mode";done
bash "$ROOT/tests/replay_cave_owner/migration_build.sh" "$work/migration"
CAVE_CARRIER_GAME=cave-owned CAVE_CARRIER_COORDINATOR="$work/migration/coordinator" python3 "$ROOT/tests/replay_cave_carrier/migrations.py" "$work/migration"
echo REPLAY_CAVE_OWNER_OK

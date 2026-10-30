#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
odin test "$ROOT/tests/replay_provision_godot_core" -collection:godot="$ROOT" -out:"$work/client"
odin check "$ROOT/replay/godot" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point -custom-attribute:gd_method
echo REPLAY_PROVISION_GODOT_CORE_OK

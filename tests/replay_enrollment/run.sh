#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
odin test "$ROOT/tests/replay_enrollment" -collection:godot="$ROOT" -define:REPLAY_ENROLLMENT_DIR="$work" -out:"$work/enrollment"
odin check "$ROOT/replay/godot" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point -custom-attribute:gd_method
echo REPLAY_ENROLLMENT_OK

#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
"${ODIN:-odin}" test "$ROOT/tests/replay_provision" -collection:godot="$ROOT" -out:"$work/provision_tests"
"${ODIN:-odin}" check "$ROOT/replay/provision" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point
echo REPLAY_PROVISION_OK

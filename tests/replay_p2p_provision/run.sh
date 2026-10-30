#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
odin test "$ROOT/tests/replay_p2p_provision" -collection:godot="$ROOT" -out:"$work/tests"
odin check "$ROOT/replay/p2p/provision" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point
echo REPLAY_P2P_PROVISION_OK

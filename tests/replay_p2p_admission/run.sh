#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="$(mktemp -d)";trap 'rm -rf "$work"' EXIT
odin test "$ROOT/tests/replay_p2p_admission" -collection:godot="$ROOT" -out:"$work/test"
echo REPLAY_P2P_ADMISSION_OK

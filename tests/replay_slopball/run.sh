#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
"${ODIN:-odin}" test "$ROOT/tests/replay_slopball" -collection:godot="$ROOT" -out:"$work/slopball"
echo REPLAY_SLOPBALL_MODEL_OK

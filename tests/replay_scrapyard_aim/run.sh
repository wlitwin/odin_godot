#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
source "$ROOT/build/common.sh"
work="${REPLAY_AIM_TEST_OUT:-$(mktemp -d)}";mkdir -p "$work"
build_scriptgen
run_scriptgen "$ROOT/examples/replay_scrapyard/scripts" "$ROOT/examples/replay_scrapyard"
"$ODIN" test "$ROOT/tests/replay_scrapyard_aim" -collection:godot="$ROOT" "${ODIN_GD_ATTRS[@]}" -out:"$work/aim-tests"
echo REPLAY_SCRAPYARD_AIM_OK

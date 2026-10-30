#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_SHARED_ALIAS_OUT:-$(mktemp -d)}";mkdir -p "$work"
odin build "$ROOT/scriptgen" -collection:godot="$ROOT" -out:"$work/scriptgen"
python3 "$ROOT/tests/replay_shared_alias/cases.py" "$work/scriptgen" "$work/cases"
SGEN_BIN="$work/scriptgen" bash "$ROOT/tests/scriptgen/run.sh"
REPLAY_HELLO_INPUT_OUT="$work/hello" bash "$ROOT/tests/replay_hello_input/run.sh"
echo REPLAY_SHARED_ALIAS_OK

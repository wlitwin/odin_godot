#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
work="$1";mkdir -p "$work/scripts" "$work/shared/hello"
cp "$ROOT/examples/replay_hello/shared/hello/"*.odin "$work/shared/hello/"
cp "$ROOT/tests/replay_hello_input/alias/probe.odin.txt" "$work/scripts/probe.odin"
odin build "$ROOT/scriptgen" -collection:godot="$ROOT" -out:"$work/scriptgen"
"$work/scriptgen" "$work/scripts" -godot:"$ROOT"

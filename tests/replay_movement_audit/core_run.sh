#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="${REPLAY_OWNER_CORE_OUT:-$(mktemp -d)}";mkdir -p "$work"
[[ -z "$(ls -A "$work")" ]] || { echo "Core audit needs an empty output directory" >&2;exit 2; }
if odin test "$ROOT/tests/replay_movement_audit/core" -collection:godot="$ROOT" -out:"$work/original" >"$work/original.log" 2>&1;then echo 'Expected owner rewind was absent';exit 1;fi
rg -q 'expected mine.x to be 140, got 100' "$work/original.log"
python3 "$ROOT/tests/replay_movement_audit/prepare_framework.py" "$work/framework" >"$work/prepare.log"
odin test "$ROOT/tests/replay_movement_audit/core" -collection:godot="$work/framework" -out:"$work/control" >"$work/control.log" 2>&1
odin test "$ROOT/tests/kitnet" -collection:godot="$work/framework" -out:"$work/kitnet" >"$work/kitnet.log" 2>&1
echo "REPLAY_OWNER_UNWIND_CORE_OK logs=$work"

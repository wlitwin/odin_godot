#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="${REPLAY_PTRCALL_ABI_OUT:-$(mktemp -d)}";mkdir -p "$work/project"
cp "$ROOT/tests/replay_ptrcall_abi/project/"* "$work/project/"
case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) exit 1;;esac
python3 "$ROOT/tests/replay_ptrcall_abi/audit.py" "$work/audit.json"
odin build "$ROOT/tests/replay_ptrcall_abi" -collection:godot="$ROOT" -build-mode:shared -out:"$work/project/libverify.$ext" >"$work/build.log" 2>&1
"$GODOT" --headless --path "$work/project" --import >"$work/run.log" 2>&1
rg -q 'PTRCALL_ABI_ENUM_OK' "$work/run.log"
rg -q 'PTRCALL_ABI_VALUES_OK signed_unsigned_8_16_32' "$work/run.log"
if rg -q 'ERROR:|Assertion|PTRCALL_ABI_CHECK_FAILED' "$work/run.log";then cat "$work/run.log";exit 1;fi
echo REPLAY_PTRCALL_ABI_OK

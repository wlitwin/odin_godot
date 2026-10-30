#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="$(mktemp -d)"
trap 'if [[ "${REPLAY_KEEP_LOGS:-0}" == 1 ]]; then echo "Gun logs: $work"; else rm -rf "$work"; fi' EXIT
python3 "$ROOT/tests/replay_gun/oracle.py" "$ROOT" "$work"
for variant in old new; do
  "${ODIN:-odin}" build "$work/$variant" -collection:godot="$ROOT" -out:"$work/$variant-bin"
  "$work/$variant-bin" >"$work/$variant.txt"
done
cmp "$work/old.txt" "$work/new.txt"
cat "$work/new.txt"
"${ODIN:-odin}" test "$ROOT/tests/replay_gun" -collection:godot="$ROOT" -out:"$work/tests"
"${ODIN:-odin}" check "$ROOT/replay/play" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point
echo REPLAY_GUN_OK

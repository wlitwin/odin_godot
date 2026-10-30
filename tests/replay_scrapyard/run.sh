#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
python3 "$ROOT/examples/replay_scrapyard/tools/stock.py" --check
work="$(mktemp -d)"
cleanup() { if [[ "${REPLAY_KEEP_LOGS:-0}" == 1 ]]; then echo "Scrapyard model logs: $work"; else rm -rf "$work"; fi; }
trap cleanup EXIT
"${ODIN:-odin}" build "$ROOT/tests/replay_scrapyard/corpus" -collection:godot="$ROOT" -out:"$work/replay"
"$work/replay" >"$work/replay.txt"
cmp "$ROOT/tests/replay_scrapyard/fixtures/arena-movement.txt" "$work/replay.txt"
baseline="${SCRAPYARD_BASELINE:-$ROOT/../scrapyard}"
if [[ -f "$baseline/scripts/arena.odin" ]]; then
  python3 "$ROOT/tests/replay_scrapyard/legacy_oracle.py" "$baseline" "$work/oracle"
  "${ODIN:-odin}" build "$work/oracle" -collection:godot="$ROOT" -out:"$work/legacy"
  "$work/legacy" >"$work/legacy.txt"
  cmp "$work/legacy.txt" "$work/replay.txt"
  echo SCRAPYARD_ARENA_MOVEMENT_EQUAL
else
  echo SCRAPYARD_CACHED_BASELINE_ONLY
  if [[ "${REPLAY_REQUIRE_BASELINE:-0}" == 1 ]]; then exit 1; fi
fi
"${ODIN:-odin}" test "$ROOT/tests/replay_scrapyard" -collection:godot="$ROOT" -out:"$work/tests"
"${ODIN:-odin}" check "$ROOT/tests/replay_scrapyard/wasm" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point
echo REPLAY_SCRAPYARD_MODEL_OK

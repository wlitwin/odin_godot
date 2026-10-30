#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="$(mktemp -d)"
trap 'if [[ "${REPLAY_KEEP_LOGS:-0}" == 1 ]]; then echo "Carom logs: $work"; else rm -rf "$work"; fi' EXIT
"${ODIN:-odin}" build "$ROOT/tests/replay_carom/corpus" -collection:godot="$ROOT" -out:"$work/new-bin"
"$work/new-bin" >"$work/new.txt"
cmp "$ROOT/tests/replay_carom/fixtures/carom-beam.txt" "$work/new.txt"
baseline="${SCRAPYARD_BASELINE:-$ROOT/../scrapyard}"
if [[ -f "$baseline/scripts/gun_lobber.odin" ]]; then
  python3 "$ROOT/tests/replay_carom/oracle.py" "$baseline" "$work"
  "${ODIN:-odin}" build "$work/old" -collection:godot="$ROOT" -out:"$work/old-bin"
  "$work/old-bin" >"$work/old.txt"
  cmp "$work/old.txt" "$work/new.txt"
  echo REPLAY_CAROM_LIVE_BASELINE_EQUAL
elif [[ "${REPLAY_REQUIRE_BASELINE:-0}" == 1 ]]; then
  echo REPLAY_CAROM_BASELINE_MISSING; exit 1
else
  echo REPLAY_CAROM_CACHED_BASELINE_ONLY
fi
cat "$work/new.txt"
"${ODIN:-odin}" test "$ROOT/tests/replay_carom" -collection:godot="$ROOT" -out:"$work/tests"
"${ODIN:-odin}" check "$ROOT/replay/play" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point
echo REPLAY_CAROM_OK

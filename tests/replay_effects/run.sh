#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="$(mktemp -d)"
trap 'if [[ "${REPLAY_KEEP_LOGS:-0}" == 1 ]]; then echo "Effect logs: $work"; else rm -rf "$work"; fi' EXIT
"${ODIN:-odin}" build "$ROOT/tests/replay_effects/corpus" -collection:godot="$ROOT" -out:"$work/new-bin"
"$work/new-bin" >"$work/new.txt"
cmp "$ROOT/tests/replay_effects/fixtures/effects.txt" "$work/new.txt"
baseline="${SCRAPYARD_BASELINE:-$ROOT/../scrapyard}"
if [[ -f "$baseline/scripts/combat.odin" ]]; then
  python3 "$ROOT/tests/replay_effects/oracle.py" "$ROOT" "$baseline" "$work"
  "${ODIN:-odin}" build "$work/old" -collection:godot="$ROOT" -out:"$work/old-bin"
  "$work/old-bin" >"$work/old.txt"
  cmp "$work/old.txt" "$work/new.txt"
  echo REPLAY_EFFECTS_LIVE_BASELINE_EQUAL
elif [[ "${REPLAY_REQUIRE_BASELINE:-0}" == 1 ]]; then
  echo REPLAY_EFFECTS_BASELINE_MISSING; exit 1
else
  echo REPLAY_EFFECTS_CACHED_BASELINE_ONLY
fi
cat "$work/new.txt"
"${ODIN:-odin}" test "$ROOT/tests/replay_effects" -collection:godot="$ROOT" -out:"$work/tests"
"${ODIN:-odin}" check "$ROOT/replay/play" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point
echo REPLAY_EFFECTS_OK

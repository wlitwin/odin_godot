#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="$(mktemp -d)"
cleanup() { if [[ "${REPLAY_KEEP_LOGS:-0}" == 1 ]]; then echo "P2P archive logs: $work"; else rm -rf "$work"; fi; }
trap cleanup EXIT
"${ODIN:-odin}" test "$ROOT/tests/replay_p2p" -collection:godot="$ROOT" -out:"$work/p2p"
"${ODIN:-odin}" check "$ROOT/tests/replay_p2p/wasm" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point
"${ODIN:-odin}" build "$ROOT/tests/replay_p2p/recording" -collection:godot="$ROOT" -out:"$work/record"
"$work/record" "$work" >"$work/recordings.txt"
"${ODIN:-odin}" build "$ROOT/tests/replay_p2p/recording_wasm" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point -out:"$work/replay.wasm"
node "$ROOT/tests/replay_p2p/recording.mjs" "$work/replay.wasm" "$work"
for mode in default speed; do
  flags=(); [[ "$mode" == speed ]] && flags=(-o:speed)
  "${ODIN:-odin}" build "$ROOT/tests/replay_p2p/rejoin_native" -collection:godot="$ROOT" "${flags[@]}" -out:"$work/rejoin-$mode"
  "$work/rejoin-$mode" >"$work/rejoin-$mode.txt"
  "${ODIN:-odin}" build "$ROOT/tests/replay_p2p/rejoin_wasm" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point "${flags[@]}" -out:"$work/rejoin-$mode.wasm"
  node "$ROOT/tests/replay_p2p/rejoin.mjs" "$work/rejoin-$mode.wasm" "$work/rejoin-$mode.txt"
done
cmp "$work/rejoin-default.txt" "$work/rejoin-speed.txt"
for mode in default speed;do
 flags=();[[ "$mode" == speed ]] && flags=(-o:speed)
 "${ODIN:-odin}" build "$ROOT/tests/replay_p2p/watch_failover_native" -collection:godot="$ROOT" "${flags[@]}" -out:"$work/watch-$mode"
 "$work/watch-$mode" >"$work/watch-$mode.txt"
 "${ODIN:-odin}" build "$ROOT/tests/replay_p2p/watch_failover_wasm" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point "${flags[@]}" -out:"$work/watch-$mode.wasm"
 node "$ROOT/tests/replay_p2p/watch_failover.mjs" "$work/watch-$mode.wasm" "$work/watch-$mode.txt"
done
cmp "$work/watch-default.txt" "$work/watch-speed.txt"
"${ODIN:-odin}" build "$ROOT/examples/replay_duel/verify" -collection:godot="$ROOT" -out:"$work/verify"
"$work/verify" "$work/session.rply"
code=0
"$work/verify" "$work/divergence.rply" >"$work/divergence.txt" || code=$?
cat "$work/divergence.txt"
if [[ "$code" != 1 ]] || ! rg -q 'error=Replay_Mismatch.*mismatch_tick=12' "$work/divergence.txt"; then exit 1; fi
echo REPLAY_P2P_OK

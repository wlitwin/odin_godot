#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
work="$(mktemp -d)"
cleanup() { if [[ "${REPLAY_KEEP_LOGS:-0}" == 1 ]]; then echo "P2P profile logs: $work"; else rm -rf "$work"; fi; }
trap cleanup EXIT
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]]; then bash "$ROOT/build/build_scripts.sh" "$ROOT/examples/replay_duel"; fi
for delay in 2 8; do
  # Match every input and world transition across delay configurations.
  RDP_PROFILE=1 RDP_DELAY="$delay" RDP_PREDICTION=8 RDP_NEUTRAL=8 RDP_WATCH=0 RDP_STAGE="" RDP_UNTIL=600 REPLAY_PREBUILT=1 REPLAY_KEEP_LOGS=0 \
    bash "$ROOT/examples/replay_duel/run.sh" >"$work/delay-$delay.log" 2>&1
  cat "$work/delay-$delay.log"
done
node "$ROOT/examples/replay_duel/profile.mjs" "$work" | tee "$work/summary.json"
echo REPLAY_DUEL_PROFILE_OK
